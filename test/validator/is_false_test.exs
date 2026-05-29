defmodule Funx.Validator.IsFalseTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.IsFalse

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.IsFalse

  describe "IsFalse validator" do
    test "passes for false" do
      assert IsFalse.validate(false) == %Right{right: false}
    end

    test "fails for true" do
      result = IsFalse.validate(true)
      assert Either.left?(result)
    end

    test "fails for falsy values" do
      result = IsFalse.validate(nil)
      assert Either.left?(result)

      result = IsFalse.validate(0)
      assert Either.left?(result)

      result = IsFalse.validate("")
      assert Either.left?(result)

      result = IsFalse.validate([false])
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        IsFalse.validate(true, message: fn _ -> "must not be enabled" end)

      assert Either.left?(result)
    end
  end

  describe "IsFalse validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert IsFalse.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing false" do
      assert IsFalse.validate(%Just{value: false}, []) == %Right{right: false}
    end

    test "fails for Just containing true" do
      result = IsFalse.validate(%Just{value: true}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing falsy value" do
      result = IsFalse.validate(%Just{value: nil}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        IsFalse.validate(%Just{value: true},
          message: fn _ -> "must not be enabled" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert IsFalse.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
