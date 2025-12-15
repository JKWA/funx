defmodule Funx.Monoid.Optics.LensCompose do
  @moduledoc """
  The `Funx.Monoid.Optics.LensCompose` module provides a monoid wrapper for sequential lens composition.

  This wrapper allows lenses to be used with generic monoid operations like `m_concat/2` and `m_append/3`,
  enabling functional composition of multiple lenses into a single focusing operation.

  ### Wrapping and Unwrapping

    - `new/1`: Wraps a lens in a `LensCompose` monoid.
    - `unwrap/1`: Extracts the lens from a `LensCompose` wrapper.

  ### Monoid Operations (via protocol)

    - `empty/1`: Returns the identity lens (leaves structure unchanged).
    - `append/2`: Composes two lenses sequentially (outer then inner).
    - `wrap/2`: Wraps a lens value into the monoid.

  ## Examples

      iex> alias Funx.Monoid.Optics.LensCompose
      iex> alias Funx.Optics.Lens
      iex> lenses = [
      ...>   Lens.key(:profile),
      ...>   Lens.key(:score)
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

defimpl Funx.Monoid, for: Funx.Monoid.Optics.LensCompose do
  alias Funx.Monoid.Optics.LensCompose
  alias Funx.Optics.Lens

  @doc """
  Returns the identity lens (views and updates the whole structure unchanged).
  """
  def empty(_) do
    LensCompose.new(Funx.Optics.Lens.identity())
  end

  @doc """
  Composes two lenses sequentially.

  The outer lens runs first, then the inner lens focuses within.
  This is the canonical implementation of lens composition.
  """
  def append(%LensCompose{lens: outer}, %LensCompose{lens: inner}) do
    composed =
      Lens.make(
        fn s ->
          s |> Lens.view!(outer) |> Lens.view!(inner)
        end,
        fn s, a ->
          inner_struct = Lens.view!(s, outer)
          updated_inner = Lens.set!(inner_struct, inner, a)
          Lens.set!(s, outer, updated_inner)
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
