defmodule Funx.Predicate.NumberTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{GreaterThanOrEqual, Number}

  describe "Number predicate standalone" do
    test "returns true for integers" do
      predicate = Number.pred()

      assert predicate.(0)
      assert predicate.(1)
      assert predicate.(-1)
      assert predicate.(1_000_000)
    end

    test "returns true for floats" do
      predicate = Number.pred()

      assert predicate.(0.0)
      assert predicate.(1.5)
      assert predicate.(-3.14)
    end

    test "returns false for non-numbers" do
      predicate = Number.pred()

      refute predicate.("5")
      refute predicate.(:five)
      refute predicate.(nil)
      refute predicate.([1, 2, 3])
    end
  end

  describe "Number predicate in DSL" do
    test "check with Number" do
      is_number_score =
        pred do
          check :score, Number
        end

      assert is_number_score.(%{score: 5})
      assert is_number_score.(%{score: 5.5})
      assert is_number_score.(%{score: 0})
      assert is_number_score.(%{score: -10})
      refute is_number_score.(%{score: "5"})
      refute is_number_score.(%{})
    end

    test "negate check with Number" do
      not_number =
        pred do
          negate check :value, Number
        end

      assert not_number.(%{value: "hello"})
      assert not_number.(%{value: :atom})
      refute not_number.(%{value: 5})
      refute not_number.(%{value: 5.5})
    end

    test "combined with other predicates" do
      non_negative_number =
        pred do
          check :count, Number
          check :count, {GreaterThanOrEqual, value: 0}
        end

      assert non_negative_number.(%{count: 5})
      assert non_negative_number.(%{count: 5.5})
      assert non_negative_number.(%{count: 0})
      refute non_negative_number.(%{count: -5})
      refute non_negative_number.(%{count: "5"})
    end
  end
end
