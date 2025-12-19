defmodule Funx.Monoid.Optics.TraversalCombine do
  @moduledoc """
  The `Funx.Monoid.Optics.TraversalCombine` module provides a monoid wrapper for parallel traversal combination.

  This wrapper allows traversals to be used with generic monoid operations like `m_concat/2`,
  enabling functional aggregation of multiple optics into a single multi-focus traversal.

  ### Wrapping and Unwrapping

    - `new/1`: Wraps a traversal in a `TraversalCombine` monoid.
    - `unwrap/1`: Extracts the traversal from a `TraversalCombine` wrapper.

  ### Monoid Operations (via protocol)

    - `empty/1`: Returns the identity traversal (no foci).
    - `append/2`: Combines two traversals by concatenating their foci.
    - `wrap/2`: Wraps an optic into a single-focus traversal.

  ## Examples

      iex> alias Funx.Monoid.Optics.TraversalCombine
      iex> alias Funx.Optics.{Lens, Traversal}
      iex> optics = [Lens.key(:name), Lens.key(:age)]
      iex> t = Funx.Monoid.Utils.m_concat(%TraversalCombine{}, optics)
      iex> Traversal.to_list(%{name: "Alice", age: 30}, t)
      ["Alice", 30]
  """

  alias Funx.Optics.Traversal

  @type t :: %__MODULE__{
          traversal: Traversal.t()
        }

  defstruct traversal: nil

  @doc """
  Wraps a traversal in a TraversalCombine monoid.
  """
  @spec new(Traversal.t()) :: t()
  def new(%Traversal{} = traversal), do: %__MODULE__{traversal: traversal}

  @doc """
  Extracts the traversal from a TraversalCombine wrapper.
  """
  @spec unwrap(t()) :: Traversal.t()
  def unwrap(%__MODULE__{traversal: traversal}), do: traversal
end

defimpl Funx.Monoid, for: Funx.Monoid.Optics.TraversalCombine do
  alias Funx.Monoid.Optics.TraversalCombine
  alias Funx.Optics.{Lens, Prism, Traversal}

  @doc """
  Returns the identity traversal (no foci).

  This is the identity element for combine: a traversal that contributes no foci.
  """
  def empty(_) do
    TraversalCombine.new(%Traversal{foci: []})
  end

  @doc """
  Combines two traversals by concatenating their foci lists.

  This is parallel composition: the resulting traversal targets all foci from both inputs.
  """
  def append(%TraversalCombine{traversal: t1}, %TraversalCombine{traversal: t2}) do
    combined = %Traversal{foci: t1.foci ++ t2.foci}
    TraversalCombine.new(combined)
  end

  @doc """
  Wraps an optic (Lens or Prism) into a single-focus traversal.
  """
  def wrap(_monoid, %Lens{} = lens) do
    TraversalCombine.new(%Traversal{foci: [lens]})
  end

  def wrap(_monoid, %Prism{} = prism) do
    TraversalCombine.new(%Traversal{foci: [prism]})
  end

  @doc """
  Extracts the traversal from the TraversalCombine wrapper.
  """
  def unwrap(%TraversalCombine{traversal: traversal}), do: traversal
end
