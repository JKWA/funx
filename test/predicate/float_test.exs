defmodule Funx.Predicate.FloatTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Float, GreaterThan}

  describe "Float predicate standalone" do
    test "returns true for floats" do
      predicate = Float.pred()

      assert predicate.(0.0)
      assert predicate.(1.5)
      assert predicate.(-3.14)
      assert predicate.(1_000_000.99)
    end

    test "returns false for integers" do
      predicate = Float.pred()

      refute predicate.(0)
      refute predicate.(1)
      refute predicate.(-5)
    end

    test "returns false for non-numbers" do
      predicate = Float.pred()

      refute predicate.("5.5")
      refute predicate.(:five)
      refute predicate.(nil)
      refute predicate.([1.0, 2.0])
    end
  end

  describe "Float predicate in DSL" do
    test "check with Float" do
      is_float_price =
        pred do
          check :price, Float
        end

      assert is_float_price.(%{price: 5.5})
      assert is_float_price.(%{price: 0.0})
      assert is_float_price.(%{price: -10.99})
      refute is_float_price.(%{price: 5})
      refute is_float_price.(%{price: "5.5"})
      refute is_float_price.(%{})
    end

    test "negate check with Float" do
      not_float =
        pred do
          negate check :value, Float
        end

      assert not_float.(%{value: 5})
      assert not_float.(%{value: "hello"})
      refute not_float.(%{value: 5.5})
    end

    test "combined with other predicates" do
      positive_float =
        pred do
          check :amount, Float
          check :amount, {GreaterThan, value: 0.0}
        end

      assert positive_float.(%{amount: 5.5})
      refute positive_float.(%{amount: 0.0})
      refute positive_float.(%{amount: -5.5})
      refute positive_float.(%{amount: 5})
    end
  end
end
