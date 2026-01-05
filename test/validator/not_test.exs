defmodule Funx.Validator.NotTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Not

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.{Any, Negative, Not, Positive, Range, Required}

  describe "Not validator with numeric validators" do
    test "passes when inner validator fails" do
      result =
        Not.validate(0,
          validator: Positive
        )

      assert result == Either.right(0)
    end

    test "fails when inner validator succeeds" do
      result =
        Not.validate(10,
          validator: Positive
        )

      assert %Either.Left{} = result
    end
  end

  describe "Not validator with optioned validators" do
    test "passes when value does not satisfy range" do
      result =
        Not.validate(25,
          validator: {Range, min: 1, max: 10}
        )

      assert result == Either.right(25)
    end

    test "fails when value satisfies range" do
      result =
        Not.validate(5,
          validator: {Range, min: 1, max: 10}
        )

      assert %Either.Left{} = result
    end
  end

  describe "Not validator with Required" do
    test "passes when Required fails" do
      result =
        Not.validate(nil,
          validator: Required
        )

      assert result == Either.right(nil)
    end

    test "fails when Required succeeds" do
      result =
        Not.validate("value",
          validator: Required
        )

      assert %Either.Left{} = result
    end
  end

  describe "Not validator with Maybe values" do
    test "passes for Nothing when inner validator fails" do
      result =
        Not.validate(%Nothing{},
          validator: Required
        )

      assert result == Either.right(%Nothing{})
    end

    test "preserves Nothing when inner validator succeeds (not applicable)" do
      result =
        Not.validate(%Nothing{},
          validator: Positive
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner validator fails and preserves input" do
      result =
        Not.validate(%Just{value: 0},
          validator: Positive
        )

      assert result == Either.right(%Just{value: 0})
    end

    test "fails for Just when inner validator succeeds" do
      result =
        Not.validate(%Just{value: 5},
          validator: Positive
        )

      assert %Either.Left{} = result
    end
  end

  describe "Not validator with custom message" do
    test "uses custom message when inner validator succeeds" do
      result =
        Not.validate(10,
          validator: Positive,
          message: fn -> "must not be positive" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["must not be positive"]}} =
               result
    end

    test "default message is used when message callback is not provided" do
      result =
        Not.validate(10,
          validator: Positive
        )

      assert %Either.Left{left: %ValidationError{errors: ["must not satisfy condition"]}} =
               result
    end
  end

  describe "Not validator argument validation" do
    test "raises when :validator option is missing" do
      assert_raise KeyError, fn ->
        Not.validate(10, [])
      end
    end
  end

  describe "Not validator composition examples" do
    test "AND of Not Positive and Not Negative passes for 0" do
      result =
        Either.validate(0, [
          fn v -> Not.validate(v, validator: Positive) end,
          fn v -> Not.validate(v, validator: Negative) end
        ])

      assert result == Either.right(0)
    end

    test "Not of Any passes when value satisfies none of the alternatives" do
      result =
        Not.validate(0,
          validator: {Any, validators: [Positive, Negative]}
        )

      assert result == Either.right(0)
    end

    test "Not of Any fails when value satisfies an alternative" do
      result =
        Not.validate(5,
          validator: {Any, validators: [Positive, Negative]}
        )

      assert %Either.Left{} = result
    end
  end
end
