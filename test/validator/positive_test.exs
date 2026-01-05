defmodule Funx.Validator.PositiveTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Positive

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Positive

  describe "Positive validator" do
    test "passes for positive numbers" do
      assert Positive.validate(1) == %Right{right: 1}
      assert Positive.validate(0.1) == %Right{right: 0.1}
    end

    test "fails for zero" do
      result = Positive.validate(0)
      assert Either.left?(result)
    end

    test "fails for negative numbers" do
      result = Positive.validate(-1)
      assert Either.left?(result)
    end

    test "supports custom message callback for validation failure" do
      result =
        Positive.validate(-1, message: fn _ -> "score must be positive" end)

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        Positive.validate("invalid", message: fn _ -> "score must be numeric" end)

      assert Either.left?(result)
    end
  end

  describe "Positive validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Positive.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing positive number" do
      assert Positive.validate(%Just{value: 5}, []) == %Right{right: 5}
    end

    test "fails for Just containing zero" do
      result = Positive.validate(%Just{value: 0}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing negative number" do
      result = Positive.validate(%Just{value: -1}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-number value" do
      result = Positive.validate(%Just{value: "not a number"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Positive.validate(%Just{value: -5}, message: fn _ -> "score must be positive" end)

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Positive.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
