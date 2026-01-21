defmodule Funx.Validator.MinLengthTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.MinLength

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.MinLength

  describe "MinLength validator" do
    test "passes when string meets minimum length" do
      assert MinLength.validate("hello", min: 3) == %Right{right: "hello"}
    end

    test "passes when string equals minimum length" do
      assert MinLength.validate("abc", min: 3) == %Right{right: "abc"}
    end

    test "fails when string is shorter than minimum" do
      result = MinLength.validate("hi", min: 5)
      assert Either.left?(result)
    end

    test "requires :min option" do
      assert_raise KeyError, fn ->
        MinLength.validate("hello", [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        MinLength.validate("hello")
      end
    end

    test "supports custom error message" do
      result =
        MinLength.validate(
          "hi",
          min: 8,
          message: fn _ -> "password is too short (minimum is 8)" end
        )

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        MinLength.validate(123, min: 3, message: fn _ -> "name must be text" end)

      assert Either.left?(result)
    end
  end

  describe "MinLength validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert MinLength.validate(%Nothing{}, min: 3) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing string meeting minimum" do
      assert MinLength.validate(%Just{value: "hello"}, min: 3) == %Right{right: "hello"}
    end

    test "fails for Just containing string too short" do
      result = MinLength.validate(%Just{value: "hi"}, min: 5)
      assert Either.left?(result)
    end

    test "fails for Just containing non-string value" do
      result = MinLength.validate(%Just{value: 123}, min: 3)
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        MinLength.validate(%Just{value: "ab"},
          min: 8,
          message: fn _ -> "password too short" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert MinLength.validate(%Nothing{}, min: 5, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
