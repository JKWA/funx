defmodule Funx.Predicate.Dsl.Block do
  @moduledoc false
  # Data structure representing a nested logical block in the Predicate DSL.
  #
  # ## Purpose
  #
  # Blocks group multiple predicates with a composition strategy:
  #   - `:all` → All children must pass (AND logic) via p_all
  #   - `:any` → At least one child must pass (OR logic) via p_any
  #
  # ## Structure
  #
  # Children can be Steps (leaf predicates) or nested Blocks, forming a tree.
  # The executor recursively walks this tree to generate the final predicate code.
  #
  # ## Examples
  #
  # Simple any block (match vip OR sponsor):
  #   any do
  #     is_vip
  #     is_sponsor
  #   end
  #
  # Nested blocks (admin OR (moderator AND verified)):
  #   any do
  #     is_admin
  #     all do
  #       is_moderator
  #       is_verified
  #     end
  #   end

  alias Funx.Predicate.Dsl.Step

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
