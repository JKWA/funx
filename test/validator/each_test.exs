defmodule Funx.Validator.EachTest do
  use ExUnit.Case, async: true

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.Each
  alias Funx.Validator.Integer
  alias Funx.Validator.Positive
  alias Funx.Validator.Range

  describe "Each validator with module validator" do
    test "passes when all elements pass" do
      result = Each.validate([1, 2, 3], validator: Positive)

      assert Either.right?(result)
      assert result == Either.right([1, 2, 3])
    end

    test "fails when one element fails" do
      result = Each.validate([1, -2, 3], validator: Positive)

      assert Either.left?(result)
    end

    test "fails when multiple elements fail and collects all errors" do
      result = Each.validate([1, -2, 3, -4], validator: Positive)

      assert Either.left?(result)
      assert %Either.Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 2
    end

    test "passes for empty list" do
      result = Each.validate([], validator: Positive)

      assert Either.right?(result)
      assert result == Either.right([])
    end
  end

  describe "Each validator with optioned validator" do
    test "passes when all elements satisfy range" do
      result = Each.validate([5, 7, 10], validator: {Range, min: 1, max: 10})

      assert Either.right?(result)
      assert result == Either.right([5, 7, 10])
    end

    test "fails when elements outside range" do
      result = Each.validate([5, 15, 10], validator: {Range, min: 1, max: 10})

      assert Either.left?(result)
    end
  end

  describe "Each validator with Maybe values" do
    test "passes for Nothing" do
      result = Each.validate(%Nothing{}, validator: Positive)

      assert Either.right?(result)
      assert result == Either.right(%Nothing{})
    end

    test "passes for Just with valid list" do
      result = Each.validate(%Just{value: [1, 2, 3]}, validator: Positive)

      assert Either.right?(result)
      assert result == Either.right([1, 2, 3])
    end

    test "fails for Just with invalid list" do
      result = Each.validate(%Just{value: [1, -2, 3]}, validator: Positive)

      assert Either.left?(result)
    end
  end

  describe "Each validator with non-list" do
    test "fails for non-list value" do
      result = Each.validate("not a list", validator: Positive)

      assert Either.left?(result)
      assert %Either.Left{left: %ValidationError{errors: ["must be a list"]}} = result
    end

    test "fails for map" do
      result = Each.validate(%{a: 1}, validator: Positive)

      assert Either.left?(result)
    end

    test "fails for integer" do
      result = Each.validate(42, validator: Positive)

      assert Either.left?(result)
    end
  end

  describe "Each validator argument validation" do
    test "raises when :validator option is missing" do
      assert_raise ArgumentError, fn ->
        Each.validate([1, 2, 3], [])
      end
    end

    test "raises when called with default opts" do
      assert_raise ArgumentError, fn ->
        Each.validate([1, 2, 3])
      end
    end

    test "raises when both :validator and :validators are provided" do
      assert_raise ArgumentError, fn ->
        Each.validate([1, 2, 3], validator: Positive, validators: [Positive, Integer])
      end
    end
  end

  describe "Each validator with function validators" do
    test "arity-1 function validator works" do
      validator = fn value ->
        if value > 0 do
          Either.right(value)
        else
          Either.left(ValidationError.new("must be positive"))
        end
      end

      result = Each.validate([1, 2, 3], validator: validator)

      assert Either.right?(result)
      assert result == Either.right([1, 2, 3])
    end

    test "arity-2 function validator works" do
      validator = fn value, _opts ->
        if value > 0 do
          Either.right(value)
        else
          Either.left(ValidationError.new("must be positive"))
        end
      end

      result = Each.validate([1, 2, 3], validator: validator)

      assert Either.right?(result)
    end

    test "arity-3 function validator works" do
      validator = fn value, _opts, _env ->
        if value > 0 do
          Either.right(value)
        else
          Either.left(ValidationError.new("must be positive"))
        end
      end

      result = Each.validate([1, 2, 3], validator: validator)

      assert Either.right?(result)
    end

    test "function validator collects all errors" do
      validator = fn value ->
        if value > 0 do
          Either.right(value)
        else
          Either.left(ValidationError.new("must be positive"))
        end
      end

      result = Each.validate([1, -2, 3, -4, -5], validator: validator)

      assert Either.left?(result)
      assert %Either.Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 3
    end
  end

  describe "Each validator with multiple validators" do
    test "passes when all elements pass all validators" do
      result = Each.validate([1, 2, 3], validators: [Positive, Integer])

      assert Either.right?(result)
      assert result == Either.right([1, 2, 3])
    end

    test "fails when element fails one of multiple validators" do
      # 1.5 is positive but not an integer
      result = Each.validate([1, 1.5, 2], validators: [Positive, Integer])

      assert Either.left?(result)
    end

    test "collects errors from multiple validators for same element" do
      # -1.5 fails both Positive and Integer
      result = Each.validate([-1.5], validators: [Positive, Integer])

      assert Either.left?(result)
      assert %Either.Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 2
    end

    test "collects errors across elements and validators" do
      # -1 fails Positive, 1.5 fails Integer, -2.5 fails both
      result = Each.validate([-1, 1.5, -2.5], validators: [Positive, Integer])

      assert Either.left?(result)
      assert %Either.Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 4
    end

    test "works with optioned validators in list" do
      result =
        Each.validate([5, 7, 10], validators: [Positive, {Range, min: 1, max: 10}])

      assert Either.right?(result)
      assert result == Either.right([5, 7, 10])
    end

    test "passes for empty list with multiple validators" do
      result = Each.validate([], validators: [Positive, Integer])

      assert Either.right?(result)
      assert result == Either.right([])
    end
  end
end
