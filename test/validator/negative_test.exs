defmodule Funx.Validator.NegativeTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Negative

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Negative

  describe "Negative validator" do
    test "passes for negative numbers" do
      assert Negative.validate(-1) == %Right{right: -1}
      assert Negative.validate(-0.1) == %Right{right: -0.1}
    end

    test "fails for zero" do
      result = Negative.validate(0)
      assert Either.left?(result)
    end

    test "fails for positive numbers" do
      result = Negative.validate(1)
      assert Either.left?(result)
    end

    test "supports custom message callback for validation failure" do
      result =
        Negative.validate(10, message: fn _ -> "temperature must be below zero" end)

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        Negative.validate("invalid", message: fn _ -> "temperature must be numeric" end)

      assert Either.left?(result)
    end
  end

  describe "Negative validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Negative.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing negative number" do
      assert Negative.validate(%Just{value: -5}, []) == %Right{right: -5}
    end

    test "fails for Just containing zero" do
      result = Negative.validate(%Just{value: 0}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing positive number" do
      result = Negative.validate(%Just{value: 5}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-number value" do
      result = Negative.validate(%Just{value: "not a number"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Negative.validate(%Just{value: 10},
          message: fn _ -> "temperature must be below zero" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Negative.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
