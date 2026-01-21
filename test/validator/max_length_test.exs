defmodule Funx.Validator.MaxLengthTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.MaxLength

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.MaxLength

  describe "MaxLength validator" do
    test "passes when string is within maximum length" do
      assert MaxLength.validate("hi", max: 5) == %Right{right: "hi"}
    end

    test "passes when string equals maximum length" do
      assert MaxLength.validate("hello", max: 5) == %Right{right: "hello"}
    end

    test "fails when string exceeds maximum" do
      result = MaxLength.validate("hello world", max: 5)
      assert Either.left?(result)
    end

    test "requires :max option" do
      assert_raise KeyError, fn ->
        MaxLength.validate("hello", [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        MaxLength.validate("hello")
      end
    end

    test "supports custom message callback" do
      result =
        MaxLength.validate("hello world",
          max: 5,
          message: fn val -> "'#{val}' is too long" end
        )

      assert Either.left?(result)
    end

    test "fails when value is not a string" do
      result = MaxLength.validate(123, max: 5)
      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        MaxLength.validate(123,
          max: 5,
          message: fn val -> "expected string, got: #{inspect(val)}" end
        )

      assert Either.left?(result)
    end
  end

  describe "MaxLength validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert MaxLength.validate(%Nothing{}, max: 5) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing string within maximum" do
      assert MaxLength.validate(%Just{value: "hi"}, max: 5) == %Right{right: "hi"}
    end

    test "fails for Just containing string too long" do
      result = MaxLength.validate(%Just{value: "hello world"}, max: 5)
      assert Either.left?(result)
    end

    test "fails for Just containing non-string value" do
      result = MaxLength.validate(%Just{value: 123}, max: 5)
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        MaxLength.validate(%Just{value: "very long bio text"},
          max: 10,
          message: fn _ -> "bio too long" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert MaxLength.validate(%Nothing{}, max: 5, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
