defmodule Funx.Predicate.PositiveTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Integer, Positive}

  describe "Positive predicate standalone" do
    test "returns true for positive numbers" do
      predicate = Positive.pred()

      assert predicate.(1)
      assert predicate.(0.1)
      assert predicate.(1_000_000)
      assert predicate.(0.0001)
    end

    test "returns false for zero" do
      predicate = Positive.pred()

      refute predicate.(0)
      refute predicate.(0.0)
    end

    test "returns false for negative numbers" do
      predicate = Positive.pred()

      refute predicate.(-1)
      refute predicate.(-0.1)
      refute predicate.(-1_000_000)
    end

    test "returns false for non-numbers" do
      predicate = Positive.pred()

      refute predicate.("5")
      refute predicate.(:positive)
      refute predicate.(nil)
      refute predicate.([1, 2, 3])
    end
  end

  describe "Positive predicate in DSL" do
    test "check with Positive" do
      positive_amount =
        pred do
          check :amount, Positive
        end

      assert positive_amount.(%{amount: 100})
      assert positive_amount.(%{amount: 0.01})
      refute positive_amount.(%{amount: 0})
      refute positive_amount.(%{amount: -50})
      refute positive_amount.(%{})
    end

    test "negate check with Positive" do
      not_positive =
        pred do
          negate check :value, Positive
        end

      assert not_positive.(%{value: 0})
      assert not_positive.(%{value: -5})
      refute not_positive.(%{value: 5})
    end

    test "combined with Integer" do
      positive_integer =
        pred do
          check :count, Integer
          check :count, Positive
        end

      assert positive_integer.(%{count: 5})
      refute positive_integer.(%{count: 5.5})
      refute positive_integer.(%{count: 0})
      refute positive_integer.(%{count: -5})
    end
  end
end
