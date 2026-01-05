defmodule Funx.Validator.EmailTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Email

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Email

  describe "Email validator" do
    test "passes for valid email format" do
      assert Email.validate("user@example.com") == %Right{right: "user@example.com"}
      assert Email.validate("test+tag@domain.co.uk") == %Right{right: "test+tag@domain.co.uk"}
    end

    test "fails for invalid email format" do
      result = Email.validate("not-an-email")
      assert Either.left?(result)
    end

    test "fails for missing @ symbol" do
      result = Email.validate("notemail.com")
      assert Either.left?(result)
    end

    test "fails for empty string" do
      result = Email.validate("")
      assert Either.left?(result)
    end

    test "supports custom message callback for validation failure" do
      result =
        Email.validate("not-an-email", message: fn _ -> "invalid email address" end)

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        Email.validate(123, message: fn _ -> "email must be text" end)

      assert Either.left?(result)
    end
  end

  describe "Email validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Email.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing valid email" do
      assert Email.validate(%Just{value: "user@example.com"}, []) ==
               %Right{right: "user@example.com"}
    end

    test "fails for Just containing invalid email" do
      result = Email.validate(%Just{value: "not-an-email"}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-string value" do
      result = Email.validate(%Just{value: 123}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Email.validate(%Just{value: "bad"}, message: fn _ -> "invalid email format" end)

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Email.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
