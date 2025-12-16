defmodule Funx.Monoid.Optics.IsoCompose do
  @moduledoc """
  The `Funx.Monoid.Optics.IsoCompose` module provides a monoid wrapper for sequential iso composition.

  This wrapper allows isos to be used with generic monoid operations like `m_concat/2` and `m_append/3`,
  enabling functional composition of multiple isos into a single bidirectional transformation.

  ### Wrapping and Unwrapping

    - `new/1`: Wraps an iso in an `IsoCompose` monoid.
    - `unwrap/1`: Extracts the iso from an `IsoCompose` wrapper.

  ### Monoid Operations (via protocol)

    - `empty/1`: Returns the identity iso (both directions are identity).
    - `append/2`: Composes two isos sequentially.
    - `wrap/2`: Wraps an iso value into the monoid.

  ## Examples

      iex> alias Funx.Monoid.Optics.IsoCompose
      iex> alias Funx.Optics.Iso
      iex> isos = [
      ...>   Iso.make(
      ...>     fn s -> String.to_integer(s) end,
      ...>     fn i -> Integer.to_string(i) end
      ...>   ),
      ...>   Iso.make(
      ...>     fn i -> i * 2 end,
      ...>     fn i -> div(i, 2) end
      ...>   )
      ...> ]
      iex> composed = Funx.Monoid.Utils.m_concat(%IsoCompose{}, isos)
      iex> Iso.view("21", composed)
      42
  """

  alias Funx.Optics.Iso

  @type t :: %__MODULE__{
          iso: Iso.t()
        }

  defstruct iso: nil

  @doc """
  Wraps an iso in an IsoCompose monoid.
  """
  @spec new(Iso.t()) :: t()
  def new(%Iso{} = iso), do: %__MODULE__{iso: iso}

  @doc """
  Extracts the iso from an IsoCompose wrapper.
  """
  @spec unwrap(t()) :: Iso.t()
  def unwrap(%__MODULE__{iso: iso}), do: iso
end

defimpl Funx.Monoid, for: Funx.Monoid.Optics.IsoCompose do
  alias Funx.Monoid.Optics.IsoCompose
  alias Funx.Optics.Iso

  @doc """
  Returns the identity iso (both directions are identity functions).
  """
  def empty(_) do
    IsoCompose.new(Iso.identity())
  end

  @doc """
  Composes two isos sequentially.

  Forward direction: applies outer's view, then inner's view
  Backward direction: applies inner's review, then outer's review
  """
  def append(%IsoCompose{iso: outer}, %IsoCompose{iso: inner}) do
    composed =
      Iso.make(
        fn s ->
          s |> Iso.view(outer) |> Iso.view(inner)
        end,
        fn a ->
          a |> Iso.review(inner) |> Iso.review(outer)
        end
      )

    IsoCompose.new(composed)
  end

  @doc """
  Wraps an iso value into an IsoCompose monoid.
  """
  def wrap(_monoid, %Iso{} = iso) do
    IsoCompose.new(iso)
  end

  @doc """
  Extracts the iso from the IsoCompose wrapper.
  """
  def unwrap(%IsoCompose{iso: iso}), do: iso
end
