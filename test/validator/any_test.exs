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

  describe "Any validator with function validators" do
    test "passes when function validator succeeds" do
      use Funx.Validate

      check_val =
        validate do
          at :type, Required
          at :number, Required
        end

      cc_val =
        validate do
          at :type, Required
          at :card_number, Required
        end

      result =
        Any.validate(
          %{type: "check", number: "12345"},
          validators: [check_val, cc_val]
        )

      assert Either.right?(result)
      assert result == Either.right(%{type: "check", number: "12345"})
    end

    test "fails when all function validators fail" do
      use Funx.Validate

      check_val =
        validate do
          at :number, Required
        end

      cc_val =
        validate do
          at :card_number, Required
        end

      result =
        Any.validate(
          %{type: "unknown"},
          validators: [check_val, cc_val]
        )

      assert Either.left?(result)
    end

    test "works with mixed module and function validators" do
      use Funx.Validate

      string_val =
        validate do
          at :value, Required
        end

      result =
        Any.validate(
          %{value: "hello"},
          validators: [Positive, string_val]
        )

      assert Either.right?(result)
      assert result == Either.right(%{value: "hello"})
    end

    test "works with function validators with options" do
      use Funx.Validate

      check_val =
        validate do
          at :routing_number, Required
        end

      cc_val =
        validate do
          at :card_number, Required
        end

      result =
        Any.validate(
          %{card_number: "4111111111111111"},
          validators: [
            {check_val, []},
            {cc_val, []}
          ]
        )

      assert Either.right?(result)
      assert result == Either.right(%{card_number: "4111111111111111"})
    end

    test "arity-1 function validator works" do
      validator1 = fn _value -> Either.left(%Funx.Errors.ValidationError{errors: ["fail"]}) end
      validator2 = fn value -> Either.right(value) end

      result = Any.validate(42, validators: [validator1, validator2])

      assert Either.right?(result)
      assert result == Either.right(42)
    end

    test "arity-2 function validator works" do
      validator1 = fn _value, _opts ->
        Either.left(%Funx.Errors.ValidationError{errors: ["fail"]})
      end

      validator2 = fn value, _opts -> Either.right(value) end

      result = Any.validate(42, validators: [validator1, validator2])

      assert Either.right?(result)
      assert result == Either.right(42)
    end

    test "arity-3 function validator works" do
      validator1 = fn _value, _opts, _env ->
        Either.left(%Funx.Errors.ValidationError{errors: ["fail"]})
      end

      validator2 = fn value, _opts, _env -> Either.right(value) end

      result = Any.validate(42, validators: [validator1, validator2])

      assert Either.right?(result)
      assert result == Either.right(42)
    end

    test "arity-3 function validator with options works" do
      # Test the {validator, opts} tuple form with arity-3 function
      validator1 = fn _value, _opts, _env ->
        Either.left(%Funx.Errors.ValidationError{errors: ["fail"]})
      end

      validator2 = fn value, opts, env ->
        # Verify options and env are passed correctly
        min = Keyword.get(opts, :min, 0)
        max_from_env = Map.get(env, :max, 100)

        if value >= min and value <= max_from_env do
          Either.right(value)
        else
          Either.left(%Funx.Errors.ValidationError{errors: ["out of range"]})
        end
      end

      result =
        Any.validate(
          42,
          [validators: [{validator1, []}, {validator2, min: 10}]],
          %{max: 50}
        )

      assert Either.right?(result)
      assert result == Either.right(42)
    end

    test "arity-2 function validator with options works" do
      # Test the {validator, opts} tuple form with arity-2 function
      validator = fn value, opts ->
        min = Keyword.get(opts, :min, 0)

        if value >= min do
          Either.right(value)
        else
          Either.left(%Funx.Errors.ValidationError{errors: ["too small"]})
        end
      end

      result = Any.validate(42, validators: [{validator, min: 10}])

      assert Either.right?(result)
      assert result == Either.right(42)
    end

    test "arity-1 function validator with options works" do
      # Test the {validator, opts} tuple form with arity-1 function
      validator = fn value ->
        if value > 0 do
          Either.right(value)
        else
          Either.left(%Funx.Errors.ValidationError{errors: ["not positive"]})
        end
      end

      result = Any.validate(42, validators: [{validator, []}])

      assert Either.right?(result)
      assert result == Either.right(42)
    end
  end
end
