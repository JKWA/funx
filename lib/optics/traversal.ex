defmodule Funx.Optics.Traversal do
  @moduledoc """
  The `Funx.Optics.Traversal` module provides a multi-focus optic for targeting multiple locations in a data structure.

  A traversal is built using `combine`, which takes multiple optics (Lens or Prism) and creates a single
  optic that can focus on all of them as a single optic.

  ## Building Traversals

    - `combine/1`: Takes a list of optics and creates a multi-focus traversal.

  ## Read Operations

    - `to_list/2`: Extracts values from lens foci and any prism foci that match.
    - `to_list_maybe/2`: Extracts values from all foci (all-or-nothing).
    - `preview/2`: Returns the first matching focus.
    - `has/2`: Returns true if at least one focus matches.

  ## Key Properties

  - **Order preservation**: Foci are traversed in the order they were combined.
  - **Lens behavior**: Lens foci require presence and raise on violation.
  - **Prism behavior**: Prism foci contribute if they match, otherwise are skipped.
  - **combine is a monoid**: Declares multiplicity, not iteration.

  ## Examples

      iex> alias Funx.Optics.{Lens, Prism, Traversal}
      iex> t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      iex> Traversal.to_list(%{name: "Alice", age: 30}, t)
      ["Alice", 30]

  With Prisms (optional foci):

      iex> alias Funx.Optics.{Lens, Prism, Traversal}
      iex> t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      iex> Traversal.to_list(%{name: "Alice"}, t)
      ["Alice"]
      iex> Traversal.to_list(%{name: "Alice", email: "alice@example.com"}, t)
      ["Alice", "alice@example.com"]
  """

  import Funx.Foldable, only: [fold_l: 3]
  import Funx.Monoid.Utils, only: [m_concat: 2]

  alias Funx.List
  alias Funx.Monad.Maybe
  alias Funx.Monoid.Optics.TraversalCombine
  alias Funx.Optics.{Lens, Prism}

  @type t :: %__MODULE__{
          foci: [Lens.t() | Prism.t()]
        }

  defstruct foci: []

  @doc false
  @spec identity() :: t()
  def identity do
    %__MODULE__{foci: []}
  end

  # ============================================================================
  # Constructors
  # ============================================================================

  @doc """
  Combines multiple optics into a single multi-focus traversal.

  This is parallel composition. It widens the focus to include all provided optics.
  The resulting traversal targets all foci simultaneously.

  ## Examples

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      iex> Traversal.to_list(%{name: "Alice", age: 30}, t)
      ["Alice", 30]

  With composed paths:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> path = Lens.compose([Lens.key(:user), Lens.key(:name)])
      iex> t = Traversal.combine([path, Lens.key(:score)])
      iex> Traversal.to_list(%{user: %{name: "Bob"}, score: 100}, t)
      ["Bob", 100]

  Empty traversal (identity):

      iex> alias Funx.Optics.Traversal
      iex> t = Traversal.combine([])
      iex> Traversal.to_list(%{name: "Alice"}, t)
      []
  """
  @spec combine([Lens.t() | Prism.t()]) :: t()
  def combine(optics) when is_list(optics) do
    m_concat(%TraversalCombine{}, optics)
  end

  # ============================================================================
  # Read Operations
  # ============================================================================

  @doc """
  Returns the first successful focus from a traversal.

  Collapses multiple foci to at most one value using first-success semantics:
  - Returns the first `Just` and ignores later matches
  - Prism `Nothing` is skipped
  - Lens throws on contract violation
  - Traversal order determines priority

  ## Examples

      iex> alias Funx.Optics.{Lens, Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      iex> Traversal.preview(%{name: "Alice"}, t)
      %Maybe.Just{value: "Alice"}

  First success wins:

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      iex> Traversal.preview(%{name: "Alice", email: "alice@example.com"}, t)
      %Maybe.Just{value: "Alice"}

  Nothing when no foci match:

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
      iex> Traversal.preview(%{name: "Alice"}, t)
      %Maybe.Nothing{}

  Lens throws on violation:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:email)])
      iex> Traversal.preview(%{name: "Alice"}, t)
      ** (KeyError) key :email not found in: %{name: "Alice"}
  """
  @spec preview(s, t()) :: Maybe.t(a) when s: term(), a: term()
  def preview(structure, %__MODULE__{foci: foci}) do
    foci
    |> Maybe.concat_map(&read_optic_as_maybe(&1, structure))
    |> List.head()
  end

  @doc """
  Returns true if at least one focus matches.

  This is a boolean query derived from `preview/2`:
  - Returns `true` if any focus matches
  - Returns `false` if all foci fail (Nothing)
  - Lens throws on contract violation

  ## Examples

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> t = Traversal.combine([Prism.key(:name)])
      iex> Traversal.has(%{name: "Alice"}, t)
      true

  No match:

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> t = Traversal.combine([Prism.key(:email)])
      iex> Traversal.has(%{name: "Alice"}, t)
      false

  Empty traversal:

      iex> alias Funx.Optics.Traversal
      iex> t = Traversal.combine([])
      iex> Traversal.has(%{name: "Alice"}, t)
      false
  """
  @spec has(s, t()) :: boolean() when s: term()
  def has(structure, %__MODULE__{} = traversal) do
    preview(structure, traversal)
    |> fold_l(fn _value -> true end, fn -> false end)
  end

  @doc """
  Extracts values from all foci into a Maybe list (all-or-nothing).

  This is the all-or-nothing version of `to_list/2`. Unlike `to_list/2` which skips
  prism foci that don't match, this operation returns Nothing if any prism focus doesn't match.

  For each focus in the traversal:
  - **Lens**: Uses `view!`, contributes one value or throws on contract violation
  - **Prism**: Uses `preview`, contributes one value if matches, otherwise returns Nothing for the entire operation

  Returns `Just(list)` only when every focus succeeds.

  This is useful for enforcing co-presence: "this structure exists in ALL these contexts."

  ## Examples

      iex> alias Funx.Optics.{Lens, Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      iex> Traversal.to_list_maybe(%{name: "Alice", email: "alice@example.com"}, t)
      %Maybe.Just{value: ["Alice", "alice@example.com"]}

  Returns Nothing if any Prism doesn't match:

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      iex> Traversal.to_list_maybe(%{name: "Alice"}, t)
      %Maybe.Nothing{}

  Lens contract violation throws:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:name)])
      iex> Traversal.to_list_maybe(%{age: 30}, t)
      ** (KeyError) key :name not found in: %{age: 30}
  """
  @spec to_list_maybe(s, t()) :: Maybe.t([a]) when s: term(), a: term()
  def to_list_maybe(structure, %__MODULE__{foci: foci}) do
    Maybe.traverse(foci, &read_optic_as_maybe(&1, structure))
  end

  @doc """
  Extracts values from all foci into a list.

  For each focus in the traversal:
  - **Lens**: Uses `view!`, contributes one value or throws on contract violation
  - **Prism**: Uses `preview`, contributes one value if matches, otherwise skips (Nothing)

  The order of values matches the combine order.

  ## Examples

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      iex> Traversal.to_list(%{name: "Alice", age: 30}, t)
      ["Alice", 30]

  With Prisms (skips Nothing):

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      iex> Traversal.to_list(%{name: "Alice"}, t)
      ["Alice"]

  Order is preserved:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:age), Lens.key(:name)])
      iex> Traversal.to_list(%{name: "Alice", age: 30}, t)
      [30, "Alice"]

  Lens contract violation throws:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> t = Traversal.combine([Lens.key(:name)])
      iex> Traversal.to_list(%{age: 30}, t)
      ** (KeyError) key :name not found in: %{age: 30}
  """
  @spec to_list(s, t()) :: [a] when s: term(), a: term()
  def to_list(structure, %__MODULE__{foci: foci}) do
    Maybe.concat_map(foci, &read_optic_as_maybe(&1, structure))
  end

  defp read_optic_as_maybe(%Lens{} = optic, structure) do
    structure |> Lens.view!(optic) |> Maybe.just()
  end

  defp read_optic_as_maybe(%Prism{} = optic, structure) do
    Prism.preview(structure, optic)
  end
end
