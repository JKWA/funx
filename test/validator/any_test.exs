defmodule Funx.Validator.AnyTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Any

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.Any
  alias Funx.Validator.Negative
  alias Funx.Validator.Positive

  alias Funx.Validator.Range
  alias Funx.Validator.Required

  describe "Any validator with numeric validators" do
    test "passes when first validator succeeds" do
      result =
        Any.validate(10,
          validators: [Positive, Negative]
        )

      assert Either.right?(result)
      assert result == Either.right(10)
    end

    test "passes when later validator succeeds" do
      result =
        Any.validate(-5,
          validators: [Positive, Negative]
        )

      assert Either.right?(result)
      assert result == Either.right(-5)
    end

    test "fails when all validators fail" do
      result =
        Any.validate(0,
          validators: [Positive, Negative]
        )

      assert Either.left?(result)
    end
  end

  describe "Any validator with optioned validators" do
    test "passes when value satisfies one range" do
      result =
        Any.validate(15,
          validators: [
            {Range, min: 1, max: 10},
            {Range, min: 11, max: 20}
          ]
        )

      assert Either.right?(result)
      assert result == Either.right(15)
    end

    test "fails when value satisfies no ranges" do
      result =
        Any.validate(25,
          validators: [
            {Range, min: 1, max: 10},
            {Range, min: 11, max: 20}
          ]
        )

      assert Either.left?(result)
    end
  end

  describe "Any validator with Required" do
    test "passes when Required succeeds" do
      result =
        Any.validate("value",
          validators: [Required, Positive]
        )

      assert Either.right?(result)
      assert result == Either.right("value")
    end

    test "fails when all validators fail" do
      result =
        Any.validate(nil,
          validators: [Required, Positive]
        )

      assert Either.left?(result)
    end
  end

  describe "Any validator with Maybe values" do
    test "passes for Nothing when any validator accepts it" do
      result =
        Any.validate(%Nothing{},
          validators: [Required, Positive]
        )

      assert Either.right?(result)
      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when any validator succeeds" do
      result =
        Any.validate(%Just{value: 5},
          validators: [Negative, Positive]
        )

      assert Either.right?(result)
      assert result == Either.right(5)
    end

    test "fails for Just when all validators fail" do
      result =
        Any.validate(%Just{value: 0},
          validators: [Positive, Negative]
        )

      assert Either.left?(result)
    end
  end

  describe "Any validator with custom message" do
    test "uses custom message when all validators fail" do
      result =
        Any.validate(0,
          validators: [Positive, Negative],
          message: fn -> "must be positive or negative" end
        )

      assert Either.left?(result)
    end

    test "custom message is not used when any validator succeeds" do
      result =
        Any.validate(5,
          validators: [Negative, Positive],
          message: fn -> "should not see this" end
        )

      assert Either.right?(result)
      assert result == Either.right(5)
    end
  end

  describe "Any validator argument validation" do
    test "raises when :validations option is missing" do
      assert_raise ArgumentError, fn ->
        Any.validate(10, [])
      end
    end

    test "raises when called with default opts (no :validations)" do
      assert_raise ArgumentError, fn ->
        Any.validate(10)
      end
    end
  end
end
