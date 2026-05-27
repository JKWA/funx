defmodule Funx.Predicate.StringTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{MinLength, String}

  describe "String predicate standalone" do
    test "returns true for strings" do
      predicate = String.pred()

      assert predicate.("")
      assert predicate.("hello")
      assert predicate.("hello world")
      assert predicate.("unicode: 你好")
    end

    test "returns false for numbers" do
      predicate = String.pred()

      refute predicate.(0)
      refute predicate.(1)
      refute predicate.(1.5)
      refute predicate.(-42)
    end

    test "returns false for non-strings" do
      predicate = String.pred()

      refute predicate.(5)
      refute predicate.(:atom)
      refute predicate.(nil)
      refute predicate.([1, 2, 3])
      refute predicate.(%{key: "value"})
    end
  end

  describe "String predicate in DSL" do
    test "check with String" do
      is_string_name =
        pred do
          check :name, String
        end

      assert is_string_name.(%{name: "Alice"})
      assert is_string_name.(%{name: ""})
      assert is_string_name.(%{name: "hello world"})
      refute is_string_name.(%{name: 42})
      refute is_string_name.(%{name: :atom})
      refute is_string_name.(%{})
    end

    test "negate check with String" do
      not_string =
        pred do
          negate check :value, String
        end

      assert not_string.(%{value: 42})
      assert not_string.(%{value: :atom})
      refute not_string.(%{value: "hello"})
    end

    test "combined with other predicates" do
      non_empty_string =
        pred do
          check :name, String
          check :name, {MinLength, min: 1}
        end

      assert non_empty_string.(%{name: "Alice"})
      assert non_empty_string.(%{name: "x"})
      refute non_empty_string.(%{name: ""})
      refute non_empty_string.(%{name: 42})
    end
  end
end
