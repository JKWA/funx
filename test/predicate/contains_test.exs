defmodule Funx.Predicate.ContainsTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  doctest Funx.Predicate.Contains

  alias Funx.Predicate.Contains

  describe "Contains predicate standalone" do
    test "returns true when list contains element" do
      predicate = Contains.pred(value: :poison_resistance)

      assert predicate.([:fire_resistance, :poison_resistance, :cold_resistance])
      assert predicate.([:poison_resistance])
      refute predicate.([:fire_resistance, :cold_resistance])
      refute predicate.([])
    end

    test "works with strings" do
      predicate = Contains.pred(value: "featured")

      assert predicate.(["new", "featured", "sale"])
      refute predicate.(["new", "sale"])
    end

    test "works with integers" do
      predicate = Contains.pred(value: 42)

      assert predicate.([1, 42, 100])
      refute predicate.([1, 2, 3])
    end

    test "returns false for non-list values" do
      predicate = Contains.pred(value: :foo)

      refute predicate.(:foo)
      refute predicate.("foo")
      refute predicate.(%{foo: :bar})
      refute predicate.(nil)
    end
  end

  describe "Contains predicate in DSL" do
    test "check with Contains using tuple syntax" do
      has_resistance =
        pred do
          check :grants, {Contains, value: :poison_resistance}
        end

      assert has_resistance.(%{grants: [:poison_resistance, :fire_resistance]})
      assert has_resistance.(%{grants: [:poison_resistance]})
      refute has_resistance.(%{grants: [:fire_resistance]})
      refute has_resistance.(%{grants: []})
      refute has_resistance.(%{})
    end

    test "check with nested path" do
      poison_resistant =
        pred do
          check [:blessing, :grants], {Contains, value: :poison_resistance}
        end

      assert poison_resistant.(%{blessing: %{grants: [:poison_resistance]}})
      refute poison_resistant.(%{blessing: %{grants: []}})
      refute poison_resistant.(%{blessing: %{}})
      refute poison_resistant.(%{})
    end

    test "negate check with Contains" do
      no_admin =
        pred do
          negate check :roles, {Contains, value: :admin}
        end

      assert no_admin.(%{roles: [:user, :guest]})
      assert no_admin.(%{roles: []})
      refute no_admin.(%{roles: [:admin, :user]})
    end

    test "combined with other predicates" do
      valid_user =
        pred do
          check :active
          check :permissions, {Contains, value: :read}
        end

      assert valid_user.(%{active: true, permissions: [:read, :write]})
      refute valid_user.(%{active: false, permissions: [:read, :write]})
      refute valid_user.(%{active: true, permissions: [:write]})
    end
  end

  describe "Contains predicate argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        Contains.pred([])
      end
    end
  end
end
