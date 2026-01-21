defmodule Funx.Validator.PatternTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Pattern

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Pattern

  describe "Pattern validator" do
    test "passes when string matches regex" do
      assert Pattern.validate("ABC123", regex: ~r/^[A-Z0-9]+$/) ==
               %Right{right: "ABC123"}
    end

    test "passes when string matches regex (explicit opts)" do
      assert Pattern.validate("ABC", regex: ~r/^[A-Z]+$/) == %Right{right: "ABC"}
    end

    test "fails when string doesn't match regex" do
      result = Pattern.validate("abc", regex: ~r/^[A-Z0-9]+$/)
      assert Either.left?(result)
    end

    test "requires :regex option" do
      assert_raise KeyError, fn ->
        Pattern.validate("hello", [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        Pattern.validate("hello")
      end
    end

    test "supports custom error message" do
      result =
        Pattern.validate(
          "123",
          regex: ~r/^[a-zA-Z]+$/,
          message: fn _ -> "must contain only letters" end
        )

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        Pattern.validate(123,
          regex: ~r/^[A-Z]+$/,
          message: fn _ -> "code must be text" end
        )

      assert Either.left?(result)
    end
  end

  describe "Pattern validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Pattern.validate(%Nothing{}, regex: ~r/^[A-Z]+$/) ==
               %Right{right: %Nothing{}}
    end

    test "passes for Just containing matching string" do
      assert Pattern.validate(%Just{value: "ABC"}, regex: ~r/^[A-Z]+$/) ==
               %Right{right: "ABC"}
    end

    test "fails for Just containing non-matching string" do
      result = Pattern.validate(%Just{value: "abc"}, regex: ~r/^[A-Z]+$/)
      assert Either.left?(result)
    end

    test "fails for Just containing non-string value" do
      result = Pattern.validate(%Just{value: 123}, regex: ~r/^[A-Z]+$/)
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Pattern.validate(%Just{value: "123"},
          regex: ~r/^[A-Z]+$/,
          message: fn _ -> "invalid code format" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Pattern.validate(%Nothing{},
               regex: ~r/^[A-Z]+$/,
               message: fn _ -> "should not see this" end
             ) ==
               %Right{right: %Nothing{}}
    end
  end
end
