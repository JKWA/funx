defmodule Funx.Monoid.LensCompose do
  @moduledoc """
  A monoid for composing lenses sequentially.

  This wrapper allows lenses to be used with generic monoid operations like
  `m_concat`, similar to how `Funx.Monoid.PrismCompose` works for prisms.

  ## Examples

      iex> alias Funx.Monoid.LensCompose
      iex> alias Funx.Optics.Lens
      iex> lenses = [
      ...>   Lens.key!(:profile),
      ...>   Lens.key!(:score)
      ...> ]
      iex> wrapped = Enum.map(lenses, &LensCompose.new/1)
      iex> composed = Funx.Monoid.Utils.m_concat(%LensCompose{}, lenses)
      iex> %{profile: %{score: 42}} |> Lens.view!(composed)
      42
  """

  alias Funx.Optics.Lens

  @type t :: %__MODULE__{
          lens: Lens.t()
        }

  defstruct lens: nil

  @doc """
  Wraps a lens in a LensCompose monoid.
  """
  @spec new(Lens.t()) :: t()
  def new(%Lens{} = lens), do: %__MODULE__{lens: lens}

  @doc """
  Extracts the lens from a LensCompose wrapper.
  """
  @spec unwrap(t()) :: Lens.t()
  def unwrap(%__MODULE__{lens: lens}), do: lens
end

defimpl Funx.Monoid, for: Funx.Monoid.LensCompose do
  alias Funx.Monoid.LensCompose
  alias Funx.Optics.Lens

  @doc """
  Returns the identity lens (views and updates the whole structure unchanged).
  """
  def empty(_) do
    LensCompose.new(Lens.make(fn s -> s end, fn _s, a -> a end))
  end

  @doc """
  Composes two lenses sequentially.

  The outer lens runs first, then the inner lens focuses within.
  This is the canonical implementation of lens composition.
  """
  def append(%LensCompose{lens: outer}, %LensCompose{lens: inner}) do
    composed = Lens.make(
      fn s ->
        s |> Lens.view!(outer) |> Lens.view!(inner)
      end,
      fn s, a ->
        inner_struct = Lens.view!(s, outer)
        updated_inner = Lens.set!(inner_struct, a, inner)
        Lens.set!(s, updated_inner, outer)
      end
    )

    LensCompose.new(composed)
  end

  @doc """
  Wraps a lens value into a LensCompose monoid.
  """
  def wrap(_monoid, %Lens{} = lens) do
    LensCompose.new(lens)
  end

  @doc """
  Extracts the lens from the LensCompose wrapper.
  """
  def unwrap(%LensCompose{lens: lens}), do: lens
end
