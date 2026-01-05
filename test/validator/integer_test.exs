defmodule Funx.Validator.IntegerTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Integer

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Integer

  describe "Integer validator" do
    test "passes for integers" do
      assert Integer.validate(42) == %Right{right: 42}
      assert Integer.validate(0) == %Right{right: 0}
      assert Integer.validate(-10) == %Right{right: -10}
    end

    test "fails for floats" do
      result = Integer.validate(3.14)
      assert Either.left?(result)
    end

    test "fails for non-numbers" do
      result = Integer.validate("42")
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Integer.validate(3.14, message: fn _ -> "count must be whole number" end)

      assert Either.left?(result)
    end
  end

  describe "Integer validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Integer.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing integer" do
      assert Integer.validate(%Just{value: 42}, []) == %Right{right: 42}
    end

    test "fails for Just containing float" do
      result = Integer.validate(%Just{value: 3.14}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-number" do
      result = Integer.validate(%Just{value: "not a number"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Integer.validate(%Just{value: 3.14},
          message: fn _ -> "count must be whole number" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Integer.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
