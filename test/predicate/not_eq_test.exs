defmodule Funx.Predicate.NotEqTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.NotEq

  defmodule CustomError do
    defstruct [:message]
  end

  defmodule OtherError do
    defstruct [:message]
  end

  describe "NotEq predicate standalone" do
    test "returns true when value does not equal reference" do
      predicate = NotEq.pred(value: :active)

      assert predicate.(:deleted)
      assert predicate.(:pending)
      refute predicate.(:active)
    end

    test "returns true when string does not equal reference" do
      predicate = NotEq.pred(value: "hello")

      assert predicate.("world")
      assert predicate.("HELLO")
      refute predicate.("hello")
    end

    test "returns true when number does not equal reference" do
      predicate = NotEq.pred(value: 42)

      assert predicate.(41)
      assert predicate.(43)
      refute predicate.(42)
    end

    test "checks struct type when expected is a module" do
      predicate = NotEq.pred(value: CustomError)

      assert predicate.(%OtherError{message: "oops"})
      refute predicate.(%CustomError{message: "oops"})
    end
  end

  describe "NotEq predicate in DSL" do
    test "check with NotEq" do
      not_deleted =
        pred do
          check :status, {NotEq, value: :deleted}
        end

      assert not_deleted.(%{status: :active})
      assert not_deleted.(%{status: :pending})
      refute not_deleted.(%{status: :deleted})
      refute not_deleted.(%{})
    end

    test "negate check with NotEq (double negation)" do
      is_deleted =
        pred do
          negate check :status, {NotEq, value: :deleted}
        end

      assert is_deleted.(%{status: :deleted})
      refute is_deleted.(%{status: :active})
    end

    test "check struct type with NotEq" do
      not_custom_error =
        pred do
          check :error, {NotEq, value: CustomError}
        end

      assert not_custom_error.(%{error: %OtherError{message: "oops"}})
      refute not_custom_error.(%{error: %CustomError{message: "oops"}})
    end
  end
end
