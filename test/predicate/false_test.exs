defmodule Funx.Predicate.IsFalseTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.IsFalse

  describe "IsFalse predicate standalone" do
    test "returns true for false value" do
      predicate = IsFalse.pred()

      assert predicate.(false)
    end

    test "returns false for true value" do
      predicate = IsFalse.pred()

      refute predicate.(true)
    end

    test "returns false for falsy values (strict equality)" do
      predicate = IsFalse.pred()

      refute predicate.(nil)
      refute predicate.(0)
      refute predicate.("")
    end

    test "returns false for truthy values" do
      predicate = IsFalse.pred()

      refute predicate.(1)
      refute predicate.("false")
      refute predicate.(:false_atom)
    end
  end

  describe "IsFalse predicate in DSL" do
    test "check with IsFalse for boolean flag" do
      is_staunched =
        pred do
          check :staunched, IsFalse
        end

      assert is_staunched.(%{staunched: false})
      refute is_staunched.(%{staunched: true})
      refute is_staunched.(%{})
    end

    test "check with IsFalse using tuple syntax" do
      is_staunched =
        pred do
          check :staunched, {IsFalse, []}
        end

      assert is_staunched.(%{staunched: false})
      refute is_staunched.(%{staunched: true})
    end

    test "check with nested path" do
      bleeding =
        pred do
          check [:bleeding, :staunched], IsFalse
        end

      assert bleeding.(%{bleeding: %{staunched: false}})
      refute bleeding.(%{bleeding: %{staunched: true}})
      refute bleeding.(%{bleeding: %{}})
      refute bleeding.(%{})
    end

    test "negate check with IsFalse" do
      is_staunched =
        pred do
          negate check :staunched, IsFalse
        end

      assert is_staunched.(%{staunched: true})
      assert is_staunched.(%{})
      refute is_staunched.(%{staunched: false})
    end

    test "multiple IsFalse checks" do
      no_flags_set =
        pred do
          check :banned, IsFalse
          check :suspended, IsFalse
          check :deleted, IsFalse
        end

      assert no_flags_set.(%{banned: false, suspended: false, deleted: false})
      refute no_flags_set.(%{banned: true, suspended: false, deleted: false})
      refute no_flags_set.(%{banned: false, suspended: true, deleted: false})
    end

    test "combined with IsTrue predicate" do
      alias Funx.Predicate.IsTrue

      active_not_banned =
        pred do
          check :active, IsTrue
          check :banned, IsFalse
        end

      assert active_not_banned.(%{active: true, banned: false})
      refute active_not_banned.(%{active: false, banned: false})
      refute active_not_banned.(%{active: true, banned: true})
    end

    test "within any block" do
      alias Funx.Predicate.IsTrue

      safe_to_proceed =
        pred do
          any do
            check :override, IsTrue
            check :blocked, IsFalse
          end
        end

      assert safe_to_proceed.(%{override: true, blocked: true})
      assert safe_to_proceed.(%{override: false, blocked: false})
      refute safe_to_proceed.(%{override: false, blocked: true})
    end
  end
end
