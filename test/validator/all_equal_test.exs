defmodule Funx.Validator.AllEqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.AllEqual

  alias Funx.Monad.Either
  alias Funx.Validator.AllEqual

  alias Funx.Monad.Maybe.{Just, Nothing}

  defp case_insensitive_eq do
    %{
      eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) == String.downcase(b)
      end,
      not_eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) != String.downcase(b)
      end
    }
  end

  describe "AllEqual validator with matching elements" do
    test "passes when all elements are the same" do
      assert AllEqual.validate([1, 1, 1]) == Either.right([1, 1, 1])
    end

    test "passes when all string elements match" do
      assert AllEqual.validate(["hello", "hello", "hello"]) ==
               Either.right(["hello", "hello", "hello"])
    end

    test "passes when all atom elements match" do
      assert AllEqual.validate([:ok, :ok, :ok]) == Either.right([:ok, :ok, :ok])
    end

    test "passes with a single element list" do
      assert AllEqual.validate([42]) == Either.right([42])
    end

    test "passes with two identical elements" do
      assert AllEqual.validate(["a", "a"]) == Either.right(["a", "a"])
    end
  end

  describe "AllEqual validator with non-matching elements" do
    test "fails when elements differ" do
      result = AllEqual.validate([1, 2, 3])
      assert Either.left?(result)
    end

    test "fails when only two elements differ" do
      result = AllEqual.validate([1, 2])
      assert Either.left?(result)
    end

    test "fails when mostly matching with one different" do
      result = AllEqual.validate([1, 1, 1, 2])
      assert Either.left?(result)
    end

    test "fails with mixed types" do
      result = AllEqual.validate([1, "1", :one])
      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with empty list" do
    test "fails for empty list" do
      result = AllEqual.validate([])
      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with non-list values" do
    test "fails when value is not a list" do
      result = AllEqual.validate("not a list")
      assert Either.left?(result)
    end

    test "fails for integer value" do
      result = AllEqual.validate(42)
      assert Either.left?(result)
    end

    test "fails for nil value" do
      result = AllEqual.validate(nil)
      assert Either.left?(result)
    end

    test "fails for map value" do
      result = AllEqual.validate(%{a: 1})
      assert Either.left?(result)
    end

    test "fails for tuple value" do
      result = AllEqual.validate({1, 2, 3})
      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with custom error messages" do
    test "supports custom message for non-matching elements" do
      result =
        AllEqual.validate([1, 2, 3],
          message: fn _ -> "all values must be identical" end
        )

      assert Either.left?(result)
    end

    test "supports custom message for non-list value" do
      result =
        AllEqual.validate("not a list",
          message: fn _ -> "expected a list" end
        )

      assert Either.left?(result)
    end

    test "supports custom message callback that uses the value" do
      result =
        AllEqual.validate(123,
          message: fn val -> "got #{val} instead of a list" end
        )

      assert Either.left?(result)
    end

    test "custom message receives the actual value for matching failure" do
      value = [1, 2, 3]

      result =
        AllEqual.validate(value,
          message: fn val -> "values #{inspect(val)} do not all match" end
        )

      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with complex data types" do
    test "passes when all map elements are equal" do
      map = %{a: 1, b: 2}
      assert AllEqual.validate([map, map, map]) == Either.right([map, map, map])
    end

    test "fails when map elements differ" do
      result = AllEqual.validate([%{a: 1}, %{a: 2}])
      assert Either.left?(result)
    end

    test "passes when all tuple elements are equal" do
      tuple = {:ok, "value"}
      assert AllEqual.validate([tuple, tuple]) == Either.right([tuple, tuple])
    end

    test "fails when tuple elements differ" do
      result = AllEqual.validate([{:ok, "a"}, {:ok, "b"}])
      assert Either.left?(result)
    end

    test "passes when all nested list elements are equal" do
      nested = [1, 2, 3]
      assert AllEqual.validate([nested, nested]) == Either.right([nested, nested])
    end

    test "fails when nested list elements differ" do
      result = AllEqual.validate([[1, 2], [1, 3]])
      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with custom Eq" do
    test "passes when all elements match using case-insensitive comparison" do
      assert AllEqual.validate(["HELLO", "hello", "HeLLo"], eq: case_insensitive_eq()) ==
               Either.right(["HELLO", "hello", "HeLLo"])
    end

    test "fails when elements differ even with case-insensitive comparison" do
      result = AllEqual.validate(["HELLO", "world"], eq: case_insensitive_eq())
      assert Either.left?(result)
    end

    test "passes with mixed case single word" do
      assert AllEqual.validate(["Test", "TEST", "test", "TeSt"], eq: case_insensitive_eq()) ==
               Either.right(["Test", "TEST", "test", "TeSt"])
    end

    test "uses default Eq.Protocol when no custom eq provided" do
      result = AllEqual.validate(["HELLO", "hello"])
      assert Either.left?(result)
    end

    test "custom Eq can be combined with custom message" do
      result =
        AllEqual.validate(["hello", "world"],
          eq: case_insensitive_eq(),
          message: fn _ -> "strings must be identical (ignoring case)" end
        )

      assert Either.left?(result)
    end
  end

  describe "AllEqual validator with Maybe types" do
    test "passes for Nothing (optional field without value)" do
      assert AllEqual.validate(%Nothing{}, []) == Either.right(%Nothing{})
    end

    test "passes for Just containing matching elements" do
      assert AllEqual.validate(%Just{value: [1, 1, 1]}, []) == Either.right([1, 1, 1])
    end

    test "fails for Just containing non-matching elements" do
      result = AllEqual.validate(%Just{value: [1, 2, 3]}, [])
      assert Either.left?(result)
    end

    test "passes for Just with single element" do
      assert AllEqual.validate(%Just{value: [42]}, []) == Either.right([42])
    end

    test "fails for Just containing non-list value" do
      result = AllEqual.validate(%Just{value: "not a list"}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing integer" do
      result = AllEqual.validate(%Just{value: 123}, [])
      assert Either.left?(result)
    end

    test "works with custom Eq on Just values" do
      assert AllEqual.validate(%Just{value: ["HELLO", "hello", "HeLLo"]},
               eq: case_insensitive_eq()
             ) ==
               Either.right(["HELLO", "hello", "HeLLo"])
    end

    test "custom message works with Just values" do
      result =
        AllEqual.validate(%Just{value: [1, 2]},
          message: fn _ -> "values must match" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom Eq" do
      assert AllEqual.validate(%Nothing{}, eq: case_insensitive_eq()) == Either.right(%Nothing{})
    end

    test "Nothing passes regardless of custom message" do
      assert AllEqual.validate(%Nothing{},
               message: fn _ -> "should not see this" end
             ) == Either.right(%Nothing{})
    end

    test "covers Just non-list branch with custom message" do
      result =
        AllEqual.validate(%Just{value: "not a list"},
          message: fn _ -> "expected list in Just" end
        )

      assert Either.left?(result)
    end
  end
end
