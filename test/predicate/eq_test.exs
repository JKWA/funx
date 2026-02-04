defmodule Funx.Predicate.EqTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.Eq

  defp case_insensitive_eq do
    %{
      eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) == String.downcase(b)
      end,
      not_eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) != String.downcase(b)
      end
    }
  end

  describe "Eq predicate standalone" do
    test "returns true for equal values" do
      predicate = Eq.pred(value: 5)

      assert predicate.(5)
      refute predicate.(6)
    end

    test "works with strings" do
      predicate = Eq.pred(value: "hello")

      assert predicate.("hello")
      refute predicate.("world")
    end

    test "works with atoms" do
      predicate = Eq.pred(value: :active)

      assert predicate.(:active)
      refute predicate.(:inactive)
    end

    test "works with custom Eq comparator" do
      predicate = Eq.pred(value: "hello", eq: case_insensitive_eq())

      assert predicate.("HELLO")
      assert predicate.("Hello")
      refute predicate.("world")
    end
  end

  describe "Eq predicate with struct module equality" do
    defmodule Purchase do
      defstruct [:id]
    end

    defmodule Refund do
      defstruct [:id]
    end

    test "passes when value is a struct and expected is its module" do
      predicate = Eq.pred(value: Purchase)

      assert predicate.(%Purchase{id: 1})
      refute predicate.(%Refund{id: 1})
    end

    test "fails when expected is a module but value is not a struct" do
      predicate = Eq.pred(value: Purchase)

      refute predicate.("purchase")
      refute predicate.(:purchase)
    end
  end

  describe "Eq predicate in DSL" do
    test "check with Eq using tuple syntax" do
      is_active =
        pred do
          check :status, {Eq, value: :active}
        end

      assert is_active.(%{status: :active})
      refute is_active.(%{status: :inactive})
    end

    test "check with Eq for string value" do
      is_admin =
        pred do
          check :role, {Eq, value: "admin"}
        end

      assert is_admin.(%{role: "admin"})
      refute is_admin.(%{role: "user"})
    end

    test "check with Eq using custom comparator" do
      eq_opts = case_insensitive_eq()

      matches_name =
        pred do
          check :name, {Eq, value: "alice", eq: eq_opts}
        end

      assert matches_name.(%{name: "ALICE"})
      assert matches_name.(%{name: "Alice"})
      refute matches_name.(%{name: "Bob"})
    end

    test "check with nested path" do
      is_completed =
        pred do
          check [:order, :status], {Eq, value: :completed}
        end

      assert is_completed.(%{order: %{status: :completed}})
      refute is_completed.(%{order: %{status: :pending}})
      refute is_completed.(%{})
    end

    test "negate check with Eq" do
      not_banned =
        pred do
          negate check :status, {Eq, value: :banned}
        end

      assert not_banned.(%{status: :active})
      refute not_banned.(%{status: :banned})
    end

    test "combined with other predicates" do
      valid_user =
        pred do
          check :status, {Eq, value: :active}
          check :age, fn age -> age >= 18 end
        end

      assert valid_user.(%{status: :active, age: 20})
      refute valid_user.(%{status: :inactive, age: 20})
      refute valid_user.(%{status: :active, age: 16})
    end
  end

  describe "Eq predicate argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        Eq.pred([])
      end
    end
  end
end
