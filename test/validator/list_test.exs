defmodule Funx.Validator.ListTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.List

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.List

  describe "List validator" do
    test "passes for lists" do
      assert List.validate([1, 2, 3]) == %Right{right: [1, 2, 3]}
      assert List.validate([]) == %Right{right: []}
      assert List.validate(["a", "b"]) == %Right{right: ["a", "b"]}
    end

    test "fails for non-lists" do
      result = List.validate("not a list")
      assert Either.left?(result)

      result = List.validate(42)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        List.validate("text", message: fn _ -> "tags must be a list" end)

      assert Either.left?(result)
    end
  end

  describe "List validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert List.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing list" do
      assert List.validate(%Just{value: [1, 2, 3]}, []) == %Right{right: [1, 2, 3]}
    end

    test "fails for Just containing non-list" do
      result = List.validate(%Just{value: "not a list"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        List.validate(%Just{value: 42},
          message: fn _ -> "tags must be a list" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert List.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
