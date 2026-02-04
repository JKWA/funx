defmodule Funx.Predicate.ComparisonTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual}

  doctest GreaterThan
  doctest GreaterThanOrEqual
  doctest LessThan
  doctest LessThanOrEqual

  describe "LessThan predicate" do
    test "returns true when value is less than reference" do
      predicate = LessThan.pred(value: 10)

      assert predicate.(5)
      assert predicate.(9)
      refute predicate.(10)
      refute predicate.(11)
    end

    test "works with strings" do
      predicate = LessThan.pred(value: "b")

      assert predicate.("a")
      refute predicate.("b")
      refute predicate.("c")
    end

    test "in DSL with check" do
      under_limit =
        pred do
          check :score, {LessThan, value: 100}
        end

      assert under_limit.(%{score: 50})
      assert under_limit.(%{score: 99})
      refute under_limit.(%{score: 100})
      refute under_limit.(%{score: 150})
    end
  end

  describe "LessThanOrEqual predicate" do
    test "returns true when value is less than or equal to reference" do
      predicate = LessThanOrEqual.pred(value: 10)

      assert predicate.(5)
      assert predicate.(10)
      refute predicate.(11)
    end

    test "works with strings" do
      predicate = LessThanOrEqual.pred(value: "b")

      assert predicate.("a")
      assert predicate.("b")
      refute predicate.("c")
    end

    test "in DSL with check" do
      at_most =
        pred do
          check :score, {LessThanOrEqual, value: 100}
        end

      assert at_most.(%{score: 50})
      assert at_most.(%{score: 100})
      refute at_most.(%{score: 101})
    end
  end

  describe "GreaterThan predicate" do
    test "returns true when value is greater than reference" do
      predicate = GreaterThan.pred(value: 10)

      assert predicate.(15)
      assert predicate.(11)
      refute predicate.(10)
      refute predicate.(5)
    end

    test "works with strings" do
      predicate = GreaterThan.pred(value: "b")

      assert predicate.("c")
      refute predicate.("b")
      refute predicate.("a")
    end

    test "in DSL with check" do
      over_limit =
        pred do
          check :score, {GreaterThan, value: 0}
        end

      assert over_limit.(%{score: 1})
      assert over_limit.(%{score: 100})
      refute over_limit.(%{score: 0})
      refute over_limit.(%{score: -5})
    end
  end

  describe "GreaterThanOrEqual predicate" do
    test "returns true when value is greater than or equal to reference" do
      predicate = GreaterThanOrEqual.pred(value: 10)

      assert predicate.(15)
      assert predicate.(10)
      refute predicate.(9)
    end

    test "works with strings" do
      predicate = GreaterThanOrEqual.pred(value: "b")

      assert predicate.("c")
      assert predicate.("b")
      refute predicate.("a")
    end

    test "in DSL with check" do
      at_least =
        pred do
          check :score, {GreaterThanOrEqual, value: 0}
        end

      assert at_least.(%{score: 0})
      assert at_least.(%{score: 100})
      refute at_least.(%{score: -1})
    end
  end

  describe "combining comparison predicates" do
    test "range check with Gte and Lt" do
      in_range =
        pred do
          check :value, {GreaterThanOrEqual, value: 0}
          check :value, {LessThan, value: 100}
        end

      assert in_range.(%{value: 0})
      assert in_range.(%{value: 50})
      assert in_range.(%{value: 99})
      refute in_range.(%{value: -1})
      refute in_range.(%{value: 100})
    end

    test "exclusive range with Gt and Lt" do
      in_range =
        pred do
          check :value, {GreaterThan, value: 0}
          check :value, {LessThan, value: 100}
        end

      refute in_range.(%{value: 0})
      assert in_range.(%{value: 1})
      assert in_range.(%{value: 99})
      refute in_range.(%{value: 100})
    end
  end
end
