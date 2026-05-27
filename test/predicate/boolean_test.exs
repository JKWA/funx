defmodule Funx.Predicate.BooleanTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Boolean, IsTrue}

  describe "Boolean predicate standalone" do
    test "returns true for booleans" do
      predicate = Boolean.pred()

      assert predicate.(true)
      assert predicate.(false)
    end

    test "returns false for non-booleans" do
      predicate = Boolean.pred()

      refute predicate.(0)
      refute predicate.(1)
      refute predicate.("true")
      refute predicate.("false")
      refute predicate.([true, false])
    end
  end

  describe "Boolean predicate in DSL" do
    test "check with Boolean" do
      is_boolean_active =
        pred do
          check :active, Boolean
        end

      assert is_boolean_active.(%{active: true})
      assert is_boolean_active.(%{active: false})
      refute is_boolean_active.(%{active: 1})
      refute is_boolean_active.(%{active: "true"})
      refute is_boolean_active.(%{})
    end

    test "negate check with Boolean" do
      not_boolean =
        pred do
          negate check :value, Boolean
        end

      assert not_boolean.(%{value: 1})
      assert not_boolean.(%{value: "true"})
      refute not_boolean.(%{value: true})
      refute not_boolean.(%{value: false})
    end

    test "combined with other predicates" do
      is_true_boolean =
        pred do
          check :enabled, Boolean
          check :enabled, IsTrue
        end

      assert is_true_boolean.(%{enabled: true})
      refute is_true_boolean.(%{enabled: false})
      refute is_true_boolean.(%{enabled: 1})
    end
  end
end
