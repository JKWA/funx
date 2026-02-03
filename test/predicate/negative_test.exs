defmodule Funx.Predicate.NegativeTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Integer, Negative}

  describe "Negative predicate standalone" do
    test "returns true for negative numbers" do
      predicate = Negative.pred()

      assert predicate.(-1)
      assert predicate.(-0.1)
      assert predicate.(-1_000_000)
      assert predicate.(-0.0001)
    end

    test "returns false for zero" do
      predicate = Negative.pred()

      refute predicate.(0)
      refute predicate.(0.0)
    end

    test "returns false for positive numbers" do
      predicate = Negative.pred()

      refute predicate.(1)
      refute predicate.(0.1)
      refute predicate.(1_000_000)
    end

    test "returns false for non-numbers" do
      predicate = Negative.pred()

      refute predicate.("-5")
      refute predicate.(:negative)
      refute predicate.(nil)
      refute predicate.([-1, -2, -3])
    end
  end

  describe "Negative predicate in DSL" do
    test "check with Negative" do
      negative_balance =
        pred do
          check :balance, Negative
        end

      assert negative_balance.(%{balance: -100})
      assert negative_balance.(%{balance: -0.01})
      refute negative_balance.(%{balance: 0})
      refute negative_balance.(%{balance: 50})
      refute negative_balance.(%{})
    end

    test "negate check with Negative" do
      not_negative =
        pred do
          negate check :value, Negative
        end

      assert not_negative.(%{value: 0})
      assert not_negative.(%{value: 5})
      refute not_negative.(%{value: -5})
    end

    test "combined with Integer" do
      negative_integer =
        pred do
          check :adjustment, Integer
          check :adjustment, Negative
        end

      assert negative_integer.(%{adjustment: -5})
      refute negative_integer.(%{adjustment: -5.5})
      refute negative_integer.(%{adjustment: 0})
      refute negative_integer.(%{adjustment: 5})
    end
  end
end
