defmodule Funx.Predicate.IsTrueTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.IsTrue

  describe "IsTrue predicate standalone" do
    test "returns true for true value" do
      predicate = IsTrue.pred([])

      assert predicate.(true)
    end

    test "returns false for false value" do
      predicate = IsTrue.pred([])

      refute predicate.(false)
    end

    test "returns false for truthy values (strict equality)" do
      predicate = IsTrue.pred([])

      refute predicate.(1)
      refute predicate.("true")
      refute predicate.(:true_atom)
      refute predicate.([])
      refute predicate.(%{})
    end

    test "returns false for nil" do
      predicate = IsTrue.pred([])

      refute predicate.(nil)
    end
  end

  describe "IsTrue predicate in DSL" do
    test "check with IsTrue for boolean flag" do
      is_active =
        pred do
          check :active, IsTrue
        end

      assert is_active.(%{active: true})
      refute is_active.(%{active: false})
      refute is_active.(%{})
    end

    test "check with IsTrue using tuple syntax" do
      is_active =
        pred do
          check :active, {IsTrue, []}
        end

      assert is_active.(%{active: true})
      refute is_active.(%{active: false})
    end

    test "check with nested path" do
      is_poisoned =
        pred do
          check [:poison, :active], IsTrue
        end

      assert is_poisoned.(%{poison: %{active: true}})
      refute is_poisoned.(%{poison: %{active: false}})
      refute is_poisoned.(%{poison: %{}})
      refute is_poisoned.(%{})
    end

    test "negate check with IsTrue" do
      not_verified =
        pred do
          negate check :verified, IsTrue
        end

      assert not_verified.(%{verified: false})
      assert not_verified.(%{})
      refute not_verified.(%{verified: true})
    end

    test "multiple IsTrue checks" do
      all_flags_set =
        pred do
          check :active, IsTrue
          check :verified, IsTrue
          check :approved, IsTrue
        end

      assert all_flags_set.(%{active: true, verified: true, approved: true})
      refute all_flags_set.(%{active: true, verified: false, approved: true})
      refute all_flags_set.(%{active: true, verified: true, approved: false})
    end

    test "combined with other predicates" do
      valid_user =
        pred do
          check :active, IsTrue
          check :age, fn age -> age >= 18 end
        end

      assert valid_user.(%{active: true, age: 20})
      refute valid_user.(%{active: false, age: 20})
      refute valid_user.(%{active: true, age: 16})
    end

    test "within any block" do
      has_access =
        pred do
          any do
            check :admin, IsTrue
            check :vip, IsTrue
          end
        end

      assert has_access.(%{admin: true, vip: false})
      assert has_access.(%{admin: false, vip: true})
      assert has_access.(%{admin: true, vip: true})
      refute has_access.(%{admin: false, vip: false})
    end
  end
end
