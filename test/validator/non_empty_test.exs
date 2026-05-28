defmodule Funx.Validator.NonEmptyTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.NonEmpty

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.NonEmpty

  describe "NonEmpty validator" do
    test "passes for non-empty lists" do
      assert NonEmpty.validate([1, 2, 3]) == %Right{right: [1, 2, 3]}
      assert NonEmpty.validate([1]) == %Right{right: [1]}
      assert NonEmpty.validate(["a", "b"]) == %Right{right: ["a", "b"]}
    end

    test "fails for empty lists" do
      result = NonEmpty.validate([])
      assert Either.left?(result)
    end

    test "fails for non-lists" do
      result = NonEmpty.validate("not a list")
      assert Either.left?(result)

      result = NonEmpty.validate(42)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        NonEmpty.validate([], message: fn _ -> "tags must not be empty" end)

      assert Either.left?(result)
    end
  end

  describe "NonEmpty validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert NonEmpty.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing non-empty list" do
      assert NonEmpty.validate(%Just{value: [1, 2, 3]}, []) == %Right{right: [1, 2, 3]}
    end

    test "fails for Just containing empty list" do
      result = NonEmpty.validate(%Just{value: []}, [])
      assert Either.left?(result)
    end

    test "fails for Just containing non-list" do
      result = NonEmpty.validate(%Just{value: "not a list"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        NonEmpty.validate(%Just{value: []},
          message: fn _ -> "tags must not be empty" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert NonEmpty.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
