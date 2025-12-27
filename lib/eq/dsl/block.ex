defmodule Funx.Eq.Dsl.Block do
  @moduledoc false
  # Data structure representing a nested logical block in the Eq DSL.
  #
  # ## Purpose
  #
  # Blocks group multiple equality checks with a composition strategy:
  #   - `:all` → All children must pass (AND logic) via concat_all
  #   - `:any` → At least one child must pass (OR logic) via concat_any
  #
  # ## Structure
  #
  # Children can be Steps (leaf comparisons) or nested Blocks, forming a tree.
  # The executor recursively walks this tree to generate the final Eq code.
  #
  # ## Examples
  #
  # Simple any block (match email OR username):
  #   any do
  #     on :email
  #     on :username
  #   end
  #
  # Nested blocks (name AND (email OR username)):
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
