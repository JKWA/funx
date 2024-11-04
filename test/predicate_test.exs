defmodule Monex.PredicateTest do
  @moduledoc false

  use ExUnit.Case
  import Monex.Foldable, only: [fold_l: 3, fold_r: 3]

  alias Monex.Predicate

  describe "p_and/2" do
    test "returns true when both predicates are true" do
      pred1 = fn x -> x > 0 end
      pred2 = fn x -> rem(x, 2) == 0 end

      combined_pred = Predicate.p_and(pred1, pred2)

      assert combined_pred.(4) == true
      assert combined_pred.(2) == true
      assert combined_pred.(1) == false
      assert combined_pred.(-2) == false
    end
  end

  describe "p_or/2" do
    test "returns true when either predicate is true" do
      pred1 = fn x -> x > 0 end
      pred2 = fn x -> rem(x, 2) == 0 end

      combined_pred = Predicate.p_or(pred1, pred2)

      assert combined_pred.(4) == true
      assert combined_pred.(1) == true
      assert combined_pred.(-2) == true
      assert combined_pred.(-1) == false
    end
  end

  describe "p_not/1" do
    test "returns true when the predicate is false" do
      pred = fn x -> x > 0 end

      negated_pred = Predicate.p_not(pred)

      assert negated_pred.(0) == true
      assert negated_pred.(-1) == true
      assert negated_pred.(1) == false
    end
  end

  describe "fold_r/3" do
    test "applies true_func when predicate returns true" do
      pred = fn -> true end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_r(pred, true_func, false_func)
      assert result == "True case executed"
    end

    test "applies false_func when predicate returns false" do
      pred = fn -> false end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_r(pred, true_func, false_func)
      assert result == "False case executed"
    end
  end

  describe "fold_l/3" do
    test "applies true_func when predicate returns true" do
      pred = fn -> true end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_l(pred, true_func, false_func)
      assert result == "True case executed"
    end

    test "applies false_func when predicate returns false" do
      pred = fn -> false end
      true_func = fn -> "True case executed" end
      false_func = fn -> "False case executed" end

      result = fold_l(pred, true_func, false_func)
      assert result == "False case executed"
    end
  end
end
