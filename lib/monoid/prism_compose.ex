defmodule Funx.Monoid.PrismCompose do
  @moduledoc """
  A monoid for composing prisms sequentially.

  This wrapper allows prisms to be used with generic monoid operations.

  ## Examples

      iex> alias Funx.Monoid.PrismCompose
      iex> alias Funx.Optics.Prism
      iex> prisms = [
      ...>   Prism.struct(CreditCard),
      ...>   Prism.key(:name)
      ...> ]
      iex> wrapped = Enum.map(prisms, &PrismCompose.new/1)
      iex> composed = Funx.Monoid.Utils.m_concat(%PrismCompose{}, wrapped)
      iex> Prism.preview(%CreditCard{name: "Alice"}, composed.prism)
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

defimpl Funx.Monoid, for: Funx.Monoid.PrismCompose do
  alias Funx.Monoid.PrismCompose
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
          outer.preview.(s)
          |> bind(fn i -> inner.preview.(i) end)
        end,
        fn a ->
          inner_value = inner.review.(a)
          outer.review.(inner_value)
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
