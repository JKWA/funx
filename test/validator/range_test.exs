defmodule Funx.Validator.RangeTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Range

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Range

  describe "Range validator (for numbers)" do
    test "passes when number is within range" do
      assert Range.validate(5, min: 1, max: 10) == %Right{right: 5}
    end

    test "passes when number equals minimum" do
      assert Range.validate(1, min: 1, max: 10) == %Right{right: 1}
    end

    test "passes when number equals maximum" do
      assert Range.validate(10, min: 1, max: 10) == %Right{right: 10}
    end

    test "fails when number is below minimum" do
      result = Range.validate(0, min: 1, max: 10)
      assert Either.left?(result)
    end

    test "fails when number is above maximum" do
      result = Range.validate(11, min: 1, max: 10)
      assert Either.left?(result)
    end

    test "supports only min" do
      assert Range.validate(100, min: 50) == %Right{right: 100}

      result = Range.validate(10, min: 50)
      assert Either.left?(result)
    end

    test "supports only max" do
      assert Range.validate(5, max: 10) == %Right{right: 5}

      result = Range.validate(20, max: 10)
      assert Either.left?(result)
    end

    test "supports custom message callback for validation failure" do
      result =
        Range.validate(150,
          min: 0,
          max: 120,
          message: fn _ -> "age out of range" end
        )

      assert Either.left?(result)
    end

    test "supports custom message callback for type error" do
      result =
        Range.validate("invalid",
          min: 0,
          max: 120,
          message: fn _ -> "age must be numeric" end
        )

      assert Either.left?(result)
    end

    test "raises when neither :min nor :max is provided" do
      assert_raise ArgumentError, fn ->
        Range.validate(5, [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise ArgumentError, fn ->
        Range.validate(5)
      end
    end
  end

  describe "Range validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Range.validate(%Nothing{}, min: 1, max: 10) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing number in range" do
      assert Range.validate(%Just{value: 5}, min: 1, max: 10) == %Right{right: 5}
    end

    test "fails for Just containing number below range" do
      result = Range.validate(%Just{value: 0}, min: 1, max: 10)
      assert Either.left?(result)
    end

    test "fails for Just containing number above range" do
      result = Range.validate(%Just{value: 15}, min: 1, max: 10)
      assert Either.left?(result)
    end

    test "fails for Just containing non-number value" do
      result = Range.validate(%Just{value: "not a number"}, min: 1, max: 10)
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Range.validate(%Just{value: 150},
          min: 0,
          max: 120,
          message: fn _ -> "age out of range" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Range.validate(%Nothing{},
               min: 1,
               max: 10,
               message: fn _ -> "should not see this" end
             ) ==
               %Right{right: %Nothing{}}
    end
  end
end
