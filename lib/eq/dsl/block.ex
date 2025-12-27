defmodule Funx.Eq.Dsl.Block do
  @moduledoc false
  # Represents a nested block (all/any) in the Eq DSL compilation pipeline.
  #
  # A Block contains a composition strategy (:all or :any) and a list of children,
  # where each child is either a Step (leaf) or another Block (nested).
  #
  # ## Examples
  #
  # Simple any block:
  #   any do
  #     on :email
  #     on :username
  #   end
  #
  # Nested blocks:
  #   all do
  #     on :name
  #     any do
  #       on :email
  #       on :username
  #     end
  #   end

  alias Funx.Eq.Dsl.Step

  @type strategy :: :all | :any
  @type child :: Step.t() | t()

  @type t :: %__MODULE__{
          strategy: strategy(),
          children: list(child()),
          __meta__: map()
        }

  defstruct [:strategy, :children, :__meta__]

  @doc """
  Creates a new block with the given strategy, children, and metadata.
  """
  @spec new(strategy(), list(child()), map()) :: t()
  def new(strategy, children, meta \\ %{}) do
    %__MODULE__{
      strategy: strategy,
      children: children,
      __meta__: meta
    }
  end
end
