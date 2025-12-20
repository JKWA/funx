defmodule Funx.Optics.Traversal do
  @moduledoc """
  The `Funx.Optics.Traversal` module provides a multi-focus optic for targeting multiple locations in a data structure.

  A traversal is built using `combine`, which takes multiple optics (Lens or Prism) and creates a single
  optic that can focus on all of them simultaneously.

  ## Building Traversals

    - `combine/1`: Takes a list of optics and creates a multi-focus traversal.

  ## Read Operations

    - `to_list/2`: Extracts values from all foci into a list.

  ## Key Properties

  - **Order preservation**: Foci are traversed in the order they were combined.
  - **Lens behavior**: Lens foci always contribute (or throw on contract violation).
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
  import Funx.Monad, only: [bind: 2, map: 2]

  alias Funx.List
  alias Funx.Monad.Maybe
  alias Funx.Monoid.Optics.TraversalCombine
  alias Funx.Optics.{Lens, Prism}

  @type t :: %__MODULE__{
          foci: [Lens.t() | Prism.t()]
        }

  defstruct foci: []

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
    |> collect_reads(structure)
    |> List.maybe_head()
  end

  @doc """
  Returns true if at least one focus exists.

  This is a boolean query derived from `preview/2`:
  - Returns `true` if any focus succeeds
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
  Applies a Maybe-returning function to all foci and rebuilds the structure.

  This is an all-or-nothing operation: it succeeds only if every focus exists
  and every function application succeeds, otherwise returns Nothing.

  For each focus:
  - **Lens**: Reads with `view!`, applies function, writes back with `set!`
  - **Prism**: Reads with `preview`, applies function, writes back with `review`

  The rebuild is lawful: Lens uses its update operation, Prism uses its write side (review).

  **Update order**: Updates are applied left-to-right in combine order.

  ## Examples

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      iex> Traversal.traverse(%{name: "Alice", age: 30}, t, fn v ->
      ...>   Maybe.just(String.upcase(to_string(v)))
      ...> end)
      %Maybe.Just{value: %{name: "ALICE", age: "30"}}

  Returns Nothing when function fails:

      iex> alias Funx.Optics.{Lens, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Lens.key(:name)])
      iex> Traversal.traverse(%{name: "Alice"}, t, fn _ -> Maybe.nothing() end)
      %Maybe.Nothing{}

  Returns Nothing when Prism doesn't match:

      iex> alias Funx.Optics.{Prism, Traversal}
      iex> alias Funx.Monad.Maybe
      iex> t = Traversal.combine([Prism.key(:email)])
      iex> Traversal.traverse(%{name: "Alice"}, t, fn v -> Maybe.just(v) end)
      %Maybe.Nothing{}
  """
  @spec traverse(s, t(), (a -> Maybe.t(b))) :: Maybe.t(s) when s: term(), a: term(), b: term()
  def traverse(structure, %__MODULE__{foci: foci}, f) when is_function(f, 1) do
    foci
    |> Maybe.traverse(&extract_and_apply(&1, structure, f))
    |> map(fn updates ->
      # Track written keys to detect overlapping writes between different foci
      {result, _written_keys} =
        Enum.reduce(updates, {structure, MapSet.new()}, fn update, {acc, written_keys} ->
          apply_optic_update(update, acc, written_keys)
        end)

      result
    end)
  end

  # Helper for traverse: extracts value from optic, applies function, returns Maybe {optic, new_val}
  defp extract_and_apply(%Lens{} = optic, structure, f) do
    structure |> Lens.view!(optic) |> f.() |> map(&{optic, &1})
  end

  defp extract_and_apply(%Prism{} = optic, structure, f) do
    structure |> Prism.preview(optic) |> bind(f) |> map(&{optic, &1})
  end

  # Helper for traverse: applies a single optic update to the structure
  # Returns {updated_structure, updated_written_keys_set}
  defp apply_optic_update({%Lens{} = optic, new_val}, acc, written_keys) do
    # Lens updates don't produce fragments, so no new keys to track
    {Lens.set!(acc, optic, new_val), written_keys}
  end

  defp apply_optic_update({%Prism{} = optic, new_val}, acc, written_keys) do
    apply_prism_update(acc, optic, new_val, written_keys)
  end

  # Prism write-back: uses review to create fragment, then merges into accumulator
  # This relies on Prism laws: review creates a lawful fragment that can be merged
  # Raises if fragment overlaps with keys written by previous foci (overlapping writes are a contract violation)
  defp apply_prism_update(acc, optic, new_val, written_keys) do
    fragment = Prism.review(new_val, optic)
    fragment_keys = MapSet.new(Map.keys(fragment))

    # Check for overlap with keys written by PREVIOUS foci in this traversal
    overlapping_keys = MapSet.intersection(fragment_keys, written_keys) |> MapSet.to_list()

    unless overlapping_keys == [] do
      raise ArgumentError,
            "Traversal contract violation: overlapping writes detected. " <>
              "Prism #{inspect(optic)} attempted to write to keys #{inspect(overlapping_keys)} " <>
              "which were already written by a previous focus. Traversal requires disjoint write regions."
    end

    # Merge fragment and update written_keys set
    updated_structure = Map.merge(acc, fragment)
    updated_written_keys = MapSet.union(written_keys, fragment_keys)

    {updated_structure, updated_written_keys}
  end

  # Helper: reads all foci and collects successful results into a list
  # Returns [a] not [Maybe a] - Nothing values are filtered out by Maybe.concat
  # Lens returns value or throws, Prism returns value or is skipped
  defp collect_reads(foci, structure) do
    foci
    |> Enum.map(&read_optic_as_maybe(&1, structure))
    |> Maybe.concat()
  end

  defp read_optic_as_maybe(%Lens{} = optic, structure) do
    structure |> Lens.view!(optic) |> Maybe.just()
  end

  defp read_optic_as_maybe(%Prism{} = optic, structure) do
    Prism.preview(structure, optic)
  end

  @doc """
  Extracts values from all foci into a Maybe list (all-or-nothing).

  This is the all-or-nothing version of `to_list/2`. Unlike `to_list/2` which filters
  out Nothing values, this operation fails if ANY focus returns Nothing.

  For each focus in the traversal:
  - **Lens**: Uses `view!`, contributes one value or throws on contract violation
  - **Prism**: Uses `preview`, contributes one value if matches, otherwise returns Nothing for the entire operation

  Returns `Just(list)` only if all foci succeed. Returns `Nothing` if any Prism doesn't match.

  This is useful for enforcing homogeneity: "this structure exists in ALL these contexts."

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
    collect_reads(foci, structure)
  end
end
