defmodule Funx.Validator.StringTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.String

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.String

  describe "String validator" do
    test "passes for strings" do
      assert String.validate("hello") == %Right{right: "hello"}
      assert String.validate("") == %Right{right: ""}
      assert String.validate("hello world") == %Right{right: "hello world"}
    end

    test "fails for numbers" do
      result = String.validate(42)
      assert Either.left?(result)
    end

    test "fails for non-strings" do
      result = String.validate(:atom)
      assert Either.left?(result)

      result = String.validate(nil)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        String.validate(42, message: fn _ -> "name must be text" end)

      assert Either.left?(result)
    end
  end

  describe "String validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert String.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing string" do
      assert String.validate(%Just{value: "hello"}, []) == %Right{right: "hello"}
    end

    test "fails for Just containing number" do
      result = String.validate(%Just{value: 42}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-string" do
      result = String.validate(%Just{value: :atom}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        String.validate(%Just{value: 42},
          message: fn _ -> "name must be text" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert String.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
