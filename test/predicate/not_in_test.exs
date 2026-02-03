defmodule Funx.Predicate.NotInTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.NotIn

  defmodule Click do
    defstruct [:x, :y]
  end

  defmodule Scroll do
    defstruct [:delta]
  end

  defmodule Submit do
    defstruct [:form]
  end

  describe "NotIn predicate standalone" do
    test "returns true when value is not in list" do
      predicate = NotIn.pred(values: [:deleted, :archived])

      assert predicate.(:active)
      assert predicate.(:pending)
      refute predicate.(:deleted)
      refute predicate.(:archived)
    end

    test "returns true when string is not in list" do
      predicate = NotIn.pred(values: ["admin", "root"])

      assert predicate.("user")
      assert predicate.("guest")
      refute predicate.("admin")
      refute predicate.("root")
    end

    test "returns true when number is not in list" do
      predicate = NotIn.pred(values: [0, -1])

      assert predicate.(1)
      assert predicate.(100)
      refute predicate.(0)
      refute predicate.(-1)
    end

    test "checks struct type when values are all modules" do
      predicate = NotIn.pred(values: [Click, Scroll])

      assert predicate.(%Submit{form: "contact"})
      refute predicate.(%Click{x: 10, y: 20})
      refute predicate.(%Scroll{delta: 5})
    end
  end

  describe "NotIn predicate in DSL" do
    test "check with NotIn" do
      not_deprecated =
        pred do
          check :status, {NotIn, values: [:deleted, :archived]}
        end

      assert not_deprecated.(%{status: :active})
      assert not_deprecated.(%{status: :pending})
      refute not_deprecated.(%{status: :deleted})
      refute not_deprecated.(%{status: :archived})
      refute not_deprecated.(%{})
    end

    test "negate check with NotIn (double negation)" do
      is_deprecated =
        pred do
          negate check :status, {NotIn, values: [:deleted, :archived]}
        end

      assert is_deprecated.(%{status: :deleted})
      assert is_deprecated.(%{status: :archived})
      refute is_deprecated.(%{status: :active})
    end

    test "check struct type with NotIn" do
      not_click_or_scroll =
        pred do
          check :event, {NotIn, values: [Click, Scroll]}
        end

      assert not_click_or_scroll.(%{event: %Submit{form: "contact"}})
      refute not_click_or_scroll.(%{event: %Click{x: 10, y: 20}})
      refute not_click_or_scroll.(%{event: %Scroll{delta: 5}})
    end
  end

  describe "combined with In" do
    alias Funx.Predicate.In

    test "NotIn and In are complementary" do
      allowed = [:active, :pending]

      in_predicate = In.pred(values: allowed)
      not_in_predicate = NotIn.pred(values: allowed)

      # For any value, exactly one should be true
      for value <- [:active, :pending, :deleted, :archived] do
        assert in_predicate.(value) != not_in_predicate.(value)
      end
    end
  end
end
