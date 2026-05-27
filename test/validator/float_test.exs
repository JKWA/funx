defmodule Funx.Validator.FloatTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Float

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Float

  describe "Float validator" do
    test "passes for floats" do
      assert Float.validate(3.14) == %Right{right: 3.14}
      assert Float.validate(0.0) == %Right{right: 0.0}
      assert Float.validate(-10.5) == %Right{right: -10.5}
    end

    test "fails for integers" do
      result = Float.validate(42)
      assert Either.left?(result)
    end

    test "fails for non-numbers" do
      result = Float.validate("3.14")
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Float.validate(42, message: fn _ -> "price must be decimal" end)

      assert Either.left?(result)
    end
  end

  describe "Float validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Float.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing float" do
      assert Float.validate(%Just{value: 3.14}, []) == %Right{right: 3.14}
    end

    test "fails for Just containing integer" do
      result = Float.validate(%Just{value: 42}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-number" do
      result = Float.validate(%Just{value: "not a number"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Float.validate(%Just{value: 42},
          message: fn _ -> "price must be decimal" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Float.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
