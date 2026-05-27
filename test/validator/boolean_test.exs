defmodule Funx.Validator.BooleanTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Boolean

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Boolean

  describe "Boolean validator" do
    test "passes for true" do
      assert Boolean.validate(true) == %Right{right: true}
    end

    test "passes for false" do
      assert Boolean.validate(false) == %Right{right: false}
    end

    test "fails for non-booleans" do
      result = Boolean.validate(1)
      assert Either.left?(result)

      result = Boolean.validate("true")
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Boolean.validate(1, message: fn _ -> "must be true or false" end)

      assert Either.left?(result)
    end
  end

  describe "Boolean validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Boolean.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing true" do
      assert Boolean.validate(%Just{value: true}, []) == %Right{right: true}
    end

    test "passes for Just containing false" do
      assert Boolean.validate(%Just{value: false}, []) == %Right{right: false}
    end

    test "fails for Just containing non-boolean" do
      result = Boolean.validate(%Just{value: 1}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Boolean.validate(%Just{value: "true"},
          message: fn _ -> "must be true or false" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Boolean.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
