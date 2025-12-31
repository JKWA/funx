defmodule Funx.FoldableTest do
  @moduledoc false
  # Comprehensive test suite for the Foldable module
  #
  # Test Organization:
  #   - fold_r (right fold for predicates)
  #   - fold_l (left fold for predicates)

  use ExUnit.Case, async: true

  import Funx.Foldable, only: [fold_l: 3, fold_r: 3]

  doctest Funx.Foldable

  # ============================================================================
  # Right Fold (fold_r)
  # ============================================================================

  describe "fold_r/3" do
    test "executes true_func when predicate returns true" do
      predicate = fn -> true end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_r(predicate, true_func, false_func)

      assert result == "True case executed"
    end

    test "executes false_func when predicate returns false" do
      predicate = fn -> false end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_r(predicate, true_func, false_func)

      assert result == "False case executed"
    end

    test "works with predicates that take arguments" do
      predicate = fn x -> x > 0 end
      true_func = fn -> :positive end
      false_func = fn -> :negative end

      # Note: fold_r evaluates the predicate, so we need a 0-arity predicate
      # For predicates with args, we can wrap them
      check_positive = fn -> predicate.(5) end
      check_negative = fn -> predicate.(-5) end

      assert fold_r(check_positive, true_func, false_func) == :positive
      assert fold_r(check_negative, true_func, false_func) == :negative
    end

    test "true_func and false_func can return different types" do
      predicate = fn -> true end
      true_func = fn -> 42 end
      false_func = fn -> "string" end

      result = fold_r(predicate, true_func, false_func)

      assert result == 42
    end

    test "functions are not evaluated until needed" do
      predicate = fn -> true end

      # false_func should not be called when predicate is true
      true_func = fn -> :ok end
      false_func = fn -> raise "Should not be called" end

      assert fold_r(predicate, true_func, false_func) == :ok
    end

    test "works with complex predicates" do
      values = [1, 2, 3, 4, 5]

      predicate = fn -> Enum.all?(values, &(&1 > 0)) end
      true_func = fn -> :all_positive end
      false_func = fn -> :has_negative end

      assert fold_r(predicate, true_func, false_func) == :all_positive
    end
  end

  # ============================================================================
  # Left Fold (fold_l)
  # ============================================================================

  describe "fold_l/3" do
    test "executes true_func when predicate returns true" do
      predicate = fn -> true end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_l(predicate, true_func, false_func)

      assert result == "True case executed"
    end

    test "executes false_func when predicate returns false" do
      predicate = fn -> false end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_l(predicate, true_func, false_func)

      assert result == "False case executed"
    end

    test "works with predicates that take arguments" do
      predicate = fn x -> x > 0 end
      true_func = fn -> :positive end
      false_func = fn -> :negative end

      check_positive = fn -> predicate.(5) end
      check_negative = fn -> predicate.(-5) end

      assert fold_l(check_positive, true_func, false_func) == :positive
      assert fold_l(check_negative, true_func, false_func) == :negative
    end

    test "true_func and false_func can return different types" do
      predicate = fn -> false end
      true_func = fn -> 42 end
      false_func = fn -> "string" end

      result = fold_l(predicate, true_func, false_func)

      assert result == "string"
    end

    test "functions are not evaluated until needed" do
      predicate = fn -> false end

      # true_func should not be called when predicate is false
      true_func = fn -> raise "Should not be called" end
      false_func = fn -> :ok end

      assert fold_l(predicate, true_func, false_func) == :ok
    end

    test "works with complex predicates" do
      values = [1, 2, 3, 4, 5]

      predicate = fn -> Enum.any?(values, &(&1 > 10)) end
      true_func = fn -> :has_large end
      false_func = fn -> :all_small end

      assert fold_l(predicate, true_func, false_func) == :all_small
    end
  end

  # ============================================================================
  # fold_r and fold_l Equivalence
  # ============================================================================

  describe "fold_r and fold_l equivalence" do
    test "fold_r and fold_l return the same result for same inputs" do
      predicate = fn -> true end
      true_func = fn -> :true_case end
      false_func = fn -> :false_case end

      assert fold_r(predicate, true_func, false_func) ==
               fold_l(predicate, true_func, false_func)
    end

    test "both handle false predicates identically" do
      predicate = fn -> false end
      true_func = fn -> :true_case end
      false_func = fn -> :false_case end

      assert fold_r(predicate, true_func, false_func) ==
               fold_l(predicate, true_func, false_func)
    end

    test "both work with side effects in the same order" do
      # Track execution order
      agent = start_supervised!({Agent, fn -> [] end})

      predicate = fn -> true end

      true_func = fn ->
        Agent.update(agent, &[:true_executed | &1])
        true
      end

      false_func = fn ->
        Agent.update(agent, &[:false_executed | &1])
        false
      end

      fold_r(predicate, true_func, false_func)
      result_r = Agent.get(agent, & &1)
      Agent.update(agent, fn _ -> [] end)

      fold_l(predicate, true_func, false_func)
      result_l = Agent.get(agent, & &1)

      assert result_r == result_l
    end
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  describe "edge cases" do
    test "works with nil returns" do
      predicate = fn -> true end
      true_func = fn -> nil end
      false_func = fn -> :not_nil end

      assert fold_r(predicate, true_func, false_func) == nil
    end

    test "works with boolean returns" do
      predicate = fn -> false end
      true_func = fn -> true end
      false_func = fn -> false end

      assert fold_r(predicate, true_func, false_func) == false
    end

    test "can nest fold operations" do
      outer_predicate = fn -> true end
      inner_predicate = fn -> false end

      inner_true = fn -> :inner_true end
      inner_false = fn -> :inner_false end

      outer_true = fn -> fold_l(inner_predicate, inner_true, inner_false) end
      outer_false = fn -> :outer_false end

      result = fold_r(outer_predicate, outer_true, outer_false)

      assert result == :inner_false
    end

    test "works with lambda predicates" do
      is_even = fn n -> rem(n, 2) == 0 end
      check_42 = fn -> is_even.(42) end

      true_func = fn -> "even" end
      false_func = fn -> "odd" end

      assert fold_r(check_42, true_func, false_func) == "even"
    end
  end
end
