defmodule Funx.Validator.ContainsTest do
  use ExUnit.Case, async: true

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator.Contains

  describe "Contains validator with matching values" do
    test "passes when list contains element" do
      result = Contains.validate([:a, :b, :c], value: :b)
      assert result == Either.right([:a, :b, :c])
    end

    test "passes with single element list" do
      result = Contains.validate([:target], value: :target)
      assert result == Either.right([:target])
    end

    test "passes with strings" do
      result = Contains.validate(["foo", "bar"], value: "bar")
      assert result == Either.right(["foo", "bar"])
    end

    test "passes with integers" do
      result = Contains.validate([1, 2, 3], value: 2)
      assert result == Either.right([1, 2, 3])
    end
  end

  describe "Contains validator with non-matching values" do
    test "fails when list does not contain element" do
      result = Contains.validate([:a, :b], value: :c)
      assert Either.left?(result)
    end

    test "fails with empty list" do
      result = Contains.validate([], value: :anything)
      assert Either.left?(result)
    end

    test "fails with non-list value" do
      result = Contains.validate(:not_a_list, value: :foo)
      assert Either.left?(result)
    end
  end

  describe "Contains validator with custom message" do
    test "uses custom message on failure" do
      result =
        Contains.validate([:a, :b],
          value: :c,
          message: fn _ -> "missing required element" end
        )

      assert %Either.Left{left: %{errors: ["missing required element"]}} = result
    end
  end

  describe "Contains validator with Maybe values" do
    test "passes for Nothing" do
      assert Contains.validate(%Nothing{}, value: :anything) == Either.right(%Nothing{})
    end

    test "passes for Just when list contains element" do
      assert Contains.validate(%Just{value: [:a, :b]}, value: :a) == Either.right([:a, :b])
    end

    test "fails for Just when list does not contain element" do
      result = Contains.validate(%Just{value: [:a, :b]}, value: :c)
      assert Either.left?(result)
    end
  end

  describe "Contains validator default message" do
    test "includes the expected element" do
      result = Contains.validate([:a], value: :missing)
      assert %Either.Left{left: %{errors: [message]}} = result
      assert message =~ "must contain"
      assert message =~ ":missing"
    end
  end

  describe "Contains validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        Contains.validate([:a, :b], [])
      end
    end
  end
end
