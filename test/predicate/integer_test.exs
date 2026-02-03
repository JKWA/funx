defmodule Funx.Predicate.IntegerTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{GreaterThan, Integer}

  describe "Integer predicate standalone" do
    test "returns true for integers" do
      predicate = Integer.pred()

      assert predicate.(0)
      assert predicate.(1)
      assert predicate.(-1)
      assert predicate.(1_000_000)
    end

    test "returns false for floats" do
      predicate = Integer.pred()

      refute predicate.(1.0)
      refute predicate.(0.5)
      refute predicate.(-3.14)
    end

    test "returns false for non-numbers" do
      predicate = Integer.pred()

      refute predicate.("5")
      refute predicate.(:five)
      refute predicate.(nil)
      refute predicate.([1, 2, 3])
    end
  end

  describe "Integer predicate in DSL" do
    test "check with Integer" do
      is_integer_count =
        pred do
          check :count, Integer
        end

      assert is_integer_count.(%{count: 5})
      assert is_integer_count.(%{count: 0})
      assert is_integer_count.(%{count: -10})
      refute is_integer_count.(%{count: 5.5})
      refute is_integer_count.(%{count: "5"})
      refute is_integer_count.(%{})
    end

    test "negate check with Integer" do
      not_integer =
        pred do
          negate check :value, Integer
        end

      assert not_integer.(%{value: 5.5})
      assert not_integer.(%{value: "hello"})
      refute not_integer.(%{value: 5})
    end

    test "combined with other predicates" do
      positive_integer =
        pred do
          check :count, Integer
          check :count, {GreaterThan, value: 0}
        end

      assert positive_integer.(%{count: 5})
      refute positive_integer.(%{count: 0})
      refute positive_integer.(%{count: -5})
      refute positive_integer.(%{count: 5.5})
    end
  end
end
