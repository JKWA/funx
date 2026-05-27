defmodule Funx.Predicate.AtomTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Atom, In}

  describe "Atom predicate standalone" do
    test "returns true for atoms" do
      predicate = Atom.pred()

      assert predicate.(:ok)
      assert predicate.(:error)
      assert predicate.(:hello_world)
      assert predicate.(true)
      assert predicate.(false)
      assert predicate.(nil)
    end

    test "returns false for non-atoms" do
      predicate = Atom.pred()

      refute predicate.(5)
      refute predicate.("atom")
      refute predicate.([1, 2, 3])
      refute predicate.(%{key: "value"})
    end
  end

  describe "Atom predicate in DSL" do
    test "check with Atom" do
      is_atom_status =
        pred do
          check :status, Atom
        end

      assert is_atom_status.(%{status: :ok})
      assert is_atom_status.(%{status: :error})
      assert is_atom_status.(%{status: :pending})
      refute is_atom_status.(%{status: "ok"})
      refute is_atom_status.(%{})
    end

    test "negate check with Atom" do
      not_atom =
        pred do
          negate check :value, Atom
        end

      assert not_atom.(%{value: "hello"})
      assert not_atom.(%{value: 42})
      refute not_atom.(%{value: :hello})
    end

    test "combined with other predicates" do
      valid_status =
        pred do
          check :status, Atom
          check :status, {In, values: [:pending, :active, :completed]}
        end

      assert valid_status.(%{status: :pending})
      assert valid_status.(%{status: :active})
      assert valid_status.(%{status: :completed})
      refute valid_status.(%{status: :invalid})
      refute valid_status.(%{status: "pending"})
    end
  end
end
