defmodule Funx.Predicate.LengthTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{MaxLength, MinLength}

  describe "MinLength predicate standalone" do
    test "returns true when string meets minimum length" do
      predicate = MinLength.pred(min: 3)

      assert predicate.("hello")
      assert predicate.("abc")
      refute predicate.("ab")
      refute predicate.("")
    end

    test "returns false for non-strings" do
      predicate = MinLength.pred(min: 1)

      refute predicate.(123)
      refute predicate.(nil)
      refute predicate.([:a, :b])
    end
  end

  describe "MaxLength predicate standalone" do
    test "returns true when string does not exceed maximum length" do
      predicate = MaxLength.pred(max: 5)

      assert predicate.("hello")
      assert predicate.("hi")
      assert predicate.("")
      refute predicate.("hello world")
    end

    test "returns false for non-strings" do
      predicate = MaxLength.pred(max: 10)

      refute predicate.(123)
      refute predicate.(nil)
      refute predicate.([:a, :b])
    end
  end

  describe "MinLength predicate in DSL" do
    test "check with MinLength" do
      long_enough =
        pred do
          check :name, {MinLength, min: 2}
        end

      assert long_enough.(%{name: "Joe"})
      assert long_enough.(%{name: "Al"})
      refute long_enough.(%{name: "J"})
      refute long_enough.(%{name: ""})
      refute long_enough.(%{})
    end

    test "negate check with MinLength" do
      too_short =
        pred do
          negate check :name, {MinLength, min: 5}
        end

      assert too_short.(%{name: "Joe"})
      refute too_short.(%{name: "Joseph"})
    end
  end

  describe "MaxLength predicate in DSL" do
    test "check with MaxLength" do
      short_enough =
        pred do
          check :code, {MaxLength, max: 10}
        end

      assert short_enough.(%{code: "ABC123"})
      assert short_enough.(%{code: ""})
      refute short_enough.(%{code: "ABCDEFGHIJK"})
      refute short_enough.(%{})
    end

    test "negate check with MaxLength" do
      too_long =
        pred do
          negate check :name, {MaxLength, max: 3}
        end

      assert too_long.(%{name: "Joseph"})
      refute too_long.(%{name: "Joe"})
    end
  end

  describe "combined length predicates" do
    test "min and max length together" do
      valid_length =
        pred do
          check :password, {MinLength, min: 8}
          check :password, {MaxLength, max: 128}
        end

      assert valid_length.(%{password: "secure123"})
      assert valid_length.(%{password: String.duplicate("a", 128)})
      refute valid_length.(%{password: "short"})
      refute valid_length.(%{password: String.duplicate("a", 129)})
    end
  end
end
