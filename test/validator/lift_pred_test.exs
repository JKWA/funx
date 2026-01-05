defmodule Funx.Validator.LiftPredicateTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.LiftPredicate

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator.LiftPredicate

  describe "LiftPredicate validator" do
    test "passes when predicate returns true" do
      assert LiftPredicate.validate(150, pred: fn v -> v > 100 end) ==
               %Right{right: 150}
    end

    test "fails when predicate returns false" do
      result = LiftPredicate.validate(50, pred: fn v -> v > 100 end)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        LiftPredicate.validate(50,
          pred: fn v -> v > 100 end,
          message: fn _ -> "must be greater than 100" end
        )

      assert Either.left?(result)
    end

    test "raises when :pred option is missing" do
      assert_raise ArgumentError, fn ->
        LiftPredicate.validate(10, [])
      end
    end

    test "raises when called with default opts (no :pred)" do
      assert_raise ArgumentError, fn ->
        LiftPredicate.validate(10)
      end
    end
  end

  describe "LiftPredicate validator with Maybe types" do
    test "passes for Nothing without invoking predicate" do
      assert LiftPredicate.validate(%Nothing{}, pred: fn _ -> false end) ==
               %Right{right: %Nothing{}}
    end

    test "passes for Just when predicate returns true" do
      assert LiftPredicate.validate(%Just{value: 200},
               pred: fn v -> v > 100 end
             ) ==
               %Right{right: 200}
    end

    test "fails for Just when predicate returns false" do
      result =
        LiftPredicate.validate(%Just{value: 50},
          pred: fn v -> v > 100 end
        )

      assert Either.left?(result)
    end

    test "supports custom message for Just values" do
      result =
        LiftPredicate.validate(%Just{value: 50},
          pred: fn v -> v > 100 end,
          message: fn _ -> "too small" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert LiftPredicate.validate(%Nothing{},
               pred: fn _ -> false end,
               message: fn _ -> "should not see this" end
             ) ==
               %Right{right: %Nothing{}}
    end
  end
end
