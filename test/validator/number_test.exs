defmodule Funx.Validator.NumberTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Number

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Number

  describe "Number validator" do
    test "passes for integers" do
      assert Number.validate(42) == %Right{right: 42}
      assert Number.validate(0) == %Right{right: 0}
      assert Number.validate(-10) == %Right{right: -10}
    end

    test "passes for floats" do
      assert Number.validate(3.14) == %Right{right: 3.14}
      assert Number.validate(0.0) == %Right{right: 0.0}
      assert Number.validate(-10.5) == %Right{right: -10.5}
    end

    test "fails for non-numbers" do
      result = Number.validate("42")
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Number.validate("42", message: fn _ -> "score must be numeric" end)

      assert Either.left?(result)
    end
  end

  describe "Number validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Number.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing integer" do
      assert Number.validate(%Just{value: 42}, []) == %Right{right: 42}
    end

    test "passes for Just containing float" do
      assert Number.validate(%Just{value: 3.14}, []) == %Right{right: 3.14}
    end

    test "fails for Just containing non-number" do
      result = Number.validate(%Just{value: "not a number"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Number.validate(%Just{value: "text"},
          message: fn _ -> "score must be numeric" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Number.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
