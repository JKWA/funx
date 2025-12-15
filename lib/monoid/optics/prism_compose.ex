defmodule Funx.Monoid.Optics.PrismCompose do
  @moduledoc """
  The `Funx.Monoid.Optics.PrismCompose` module provides a monoid wrapper for sequential prism composition.

  This wrapper allows prisms to be used with generic monoid operations like `m_concat/2` and `m_append/3`,
  enabling functional composition of multiple prisms into a single partial focusing operation.

  ### Wrapping and Unwrapping

    - `new/1`: Wraps a prism in a `PrismCompose` monoid.
    - `unwrap/1`: Extracts the prism from a `PrismCompose` wrapper.

  ### Monoid Operations (via protocol)

    - `empty/1`: Returns the identity prism (accepts all values).
    - `append/2`: Composes two prisms sequentially (outer then inner).
    - `wrap/2`: Wraps a prism value into the monoid.

  ## Examples

      iex> alias Funx.Monoid.Optics.PrismCompose
      iex> alias Funx.Optics.Prism
      iex> prisms = [
      ...>   Prism.key(:account),
      ...>   Prism.key(:name)
      ...> ]
      iex> wrapped = Enum.map(prisms, &PrismCompose.new/1)
      iex> composed = Funx.Monoid.Utils.m_concat(%PrismCompose{}, prisms)
      iex> Prism.preview(%{account: %{name: "Alice"}}, composed)
      %Funx.Monad.Maybe.Just{value: "Alice"}
  """

  alias Funx.Optics.Prism

  @type t :: %__MODULE__{
          prism: Prism.t()
        }

  defstruct prism: nil

  @doc """
  Wraps a prism in a PrismCompose monoid.
  """
  @spec new(Prism.t()) :: t()
  def new(%Prism{} = prism), do: %__MODULE__{prism: prism}

  @doc """
  Extracts the prism from a PrismCompose wrapper.
  """
  @spec unwrap(t()) :: Prism.t()
  def unwrap(%__MODULE__{prism: prism}), do: prism
end

defimpl Funx.Monoid, for: Funx.Monoid.Optics.PrismCompose do
  alias Funx.Monoid.Optics.PrismCompose
  alias Funx.Optics.Prism

  @doc """
  Returns the identity prism (accepts all values).
  """
  def empty(_) do
    PrismCompose.new(Prism.identity())
  end

  @doc """
  Composes two prisms sequentially.

  The outer prism runs first; if it succeeds, the inner prism runs next.
  This is the canonical implementation of prism composition.
  """
  def append(%PrismCompose{prism: outer}, %PrismCompose{prism: inner}) do
    import Funx.Monad, only: [bind: 2]

    composed =
      Prism.make(
        fn s ->
          Prism.preview(s, outer)
          |> bind(fn i -> Prism.preview(i, inner) end)
        end,
        fn a ->
          inner_value = Prism.review(a, inner)
          Prism.review(inner_value, outer)
        end
      )

    PrismCompose.new(composed)
  end

  @doc """
  Wraps a prism value into a PrismCompose monoid.
  """
  def wrap(_monoid, %Prism{} = prism) do
    PrismCompose.new(prism)
  end

  @doc """
  Extracts the prism from the PrismCompose wrapper.
  """
  def unwrap(%PrismCompose{prism: prism}), do: prism
end
