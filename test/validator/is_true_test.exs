defmodule Funx.Validator.IsTrueTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.IsTrue

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.IsTrue

  describe "IsTrue validator" do
    test "passes for true" do
      assert IsTrue.validate(true) == %Right{right: true}
    end

    test "fails for false" do
      result = IsTrue.validate(false)
      assert Either.left?(result)
    end

    test "fails for truthy values" do
      result = IsTrue.validate(1)
      assert Either.left?(result)

      result = IsTrue.validate("true")
      assert Either.left?(result)

      result = IsTrue.validate([true])
      assert Either.left?(result)
    end

    test "fails for nil" do
      result = IsTrue.validate(nil)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        IsTrue.validate(false, message: fn _ -> "must accept terms" end)

      assert Either.left?(result)
    end
  end

  describe "IsTrue validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert IsTrue.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing true" do
      assert IsTrue.validate(%Just{value: true}, []) == %Right{right: true}
    end

    test "fails for Just containing false" do
      result = IsTrue.validate(%Just{value: false}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing truthy value" do
      result = IsTrue.validate(%Just{value: 1}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        IsTrue.validate(%Just{value: false},
          message: fn _ -> "must accept terms" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert IsTrue.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
