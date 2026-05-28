defmodule Funx.Validator.NotBlankTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.NotBlank

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.NotBlank

  describe "NotBlank validator" do
    test "passes for non-blank strings" do
      assert NotBlank.validate("hello") == %Right{right: "hello"}
      assert NotBlank.validate("hello world") == %Right{right: "hello world"}
      assert NotBlank.validate("  hello  ") == %Right{right: "  hello  "}
      assert NotBlank.validate("a") == %Right{right: "a"}
    end

    test "fails for blank strings" do
      result = NotBlank.validate("")
      assert Either.left?(result)

      result = NotBlank.validate("   ")
      assert Either.left?(result)

      result = NotBlank.validate("\n\t ")
      assert Either.left?(result)
    end

    test "fails for non-strings" do
      result = NotBlank.validate(42)
      assert Either.left?(result)

      result = NotBlank.validate(nil)
      assert Either.left?(result)

      result = NotBlank.validate(:atom)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        NotBlank.validate("", message: fn _ -> "name is required" end)

      assert Either.left?(result)
    end
  end

  describe "NotBlank validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert NotBlank.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing non-blank string" do
      assert NotBlank.validate(%Just{value: "hello"}, []) == %Right{right: "hello"}
    end

    test "fails for Just containing blank string" do
      result = NotBlank.validate(%Just{value: ""}, [])
      assert Either.left?(result)

      result = NotBlank.validate(%Just{value: "   "}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-string" do
      result = NotBlank.validate(%Just{value: 42}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        NotBlank.validate(%Just{value: ""},
          message: fn _ -> "description cannot be blank" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert NotBlank.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
