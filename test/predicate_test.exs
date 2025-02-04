defmodule Monex.PredicateTest do
  @moduledoc false

  use ExUnit.Case
  import Monex.Foldable, only: [fold_l: 3, fold_r: 3]

  alias Monex.Predicate
  alias Monex.Test.Person

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

  def adult?(%Person{age: age}), do: age >= 18

  def vip?(%Person{ticket: :vip}), do: true
  def vip?(_), do: false

  describe "p_all" do
    test "combines list of predicates using AND" do
      can_enter = Predicate.p_all([&adult?/1, &vip?/1])

      assert can_enter.(%Person{age: 20, ticket: :vip})
      refute can_enter.(%Person{age: 20, ticket: :basic})
      refute can_enter.(%Person{age: 17, ticket: :vip})
    end

    test "combines list of one predicate with AND" do
      can_enter = Predicate.p_all([&vip?/1])

      assert can_enter.(%Person{age: 20, ticket: :vip})
      refute can_enter.(%Person{age: 20, ticket: :basic})
      assert can_enter.(%Person{age: 17, ticket: :vip})
    end

    test "combines no predicates as true" do
      can_enter = Predicate.p_all([])

      assert can_enter.(%Person{age: 20, ticket: :vip})
      assert can_enter.(%Person{age: 20, ticket: :basic})
      assert can_enter.(%Person{age: 17, ticket: :vip})
    end
  end

  describe "p_any/1" do
    test "combines list of predicates using OR" do
      can_enter = Predicate.p_any([&adult?/1, &vip?/1])

      assert can_enter.(%Person{age: 20, ticket: :vip})
      assert can_enter.(%Person{age: 20, ticket: :basic})
      assert can_enter.(%Person{age: 17, ticket: :vip})
      refute can_enter.(%Person{age: 17, ticket: :basic})
    end

    test "combines list of one predicate with OR" do
      can_enter = Predicate.p_any([&vip?/1])

      assert can_enter.(%Person{age: 20, ticket: :vip})
      refute can_enter.(%Person{age: 20, ticket: :basic})
      assert can_enter.(%Person{age: 17, ticket: :vip})
      refute can_enter.(%Person{age: 17, ticket: :basic})
    end

    test "combines no predicates as false" do
      can_enter = Predicate.p_any([])

      refute can_enter.(%Person{age: 20, ticket: :vip})
      refute can_enter.(%Person{age: 20, ticket: :basic})
      refute can_enter.(%Person{age: 17, ticket: :vip})
      refute can_enter.(%Person{age: 17, ticket: :basic})
    end
  end

  describe "p_none/1" do
    test "combines list of predicates using AND and negates" do
      can_not_enter = Predicate.p_none([&adult?/1, &vip?/1])

      refute can_not_enter.(%Person{age: 20, ticket: :vip})
      refute can_not_enter.(%Person{age: 20, ticket: :basic})
      assert can_not_enter.(%Person{age: 17, ticket: :basic})
    end

    test "combines list of one predicate with AND and negates" do
      can_not_enter = Predicate.p_none([&vip?/1])

      refute can_not_enter.(%Person{age: 20, ticket: :vip})
      assert can_not_enter.(%Person{age: 20, ticket: :basic})
      assert can_not_enter.(%Person{age: 17, ticket: :basic})
    end

    test "combines no predicates as true" do
      can_not_enter = Predicate.p_none([])

      assert can_not_enter.(%Person{age: 20, ticket: :vip})
      assert can_not_enter.(%Person{age: 20, ticket: :basic})
      assert can_not_enter.(%Person{age: 17, ticket: :vip})
    end
  end
end
