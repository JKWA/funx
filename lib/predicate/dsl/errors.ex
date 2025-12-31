defmodule Funx.Predicate.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Predicate DSL

  @doc "Error: Empty block"
  def empty_block(block_type) do
    """
    Empty `#{block_type}` block detected.

    Blocks must contain at least one predicate.

    Valid:
      #{block_type} do
        is_admin
      end

    Invalid:
      #{block_type} do
      end
    """
  end

  @doc "Error: negate without predicate"
  def negate_without_predicate do
    """
    The `negate` directive requires a predicate.

    Valid:
      negate is_banned
      negate &is_suspended/1

    Invalid:
      negate
    """
  end
end
