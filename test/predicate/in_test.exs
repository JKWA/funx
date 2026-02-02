defmodule Funx.Predicate.InTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.In

  describe "In predicate standalone" do
    test "returns true when value is in list" do
      predicate = In.pred(values: [:active, :pending, :completed])

      assert predicate.(:active)
      assert predicate.(:pending)
      assert predicate.(:completed)
      refute predicate.(:cancelled)
      refute predicate.(:unknown)
    end

    test "works with strings" do
      predicate = In.pred(values: ["red", "green", "blue"])

      assert predicate.("red")
      assert predicate.("green")
      refute predicate.("yellow")
    end

    test "works with integers" do
      predicate = In.pred(values: [1, 2, 3])

      assert predicate.(1)
      assert predicate.(2)
      refute predicate.(4)
    end
  end

  describe "In predicate with struct modules" do
    defmodule Click do
      defstruct [:x, :y]
    end

    defmodule Scroll do
      defstruct [:delta]
    end

    defmodule Submit do
      defstruct [:form_id]
    end

    test "matches struct by module" do
      predicate = In.pred(values: [Click, Scroll])

      assert predicate.(%Click{x: 10, y: 20})
      assert predicate.(%Scroll{delta: 5})
      refute predicate.(%Submit{form_id: "form1"})
    end
  end

  describe "In predicate in DSL" do
    test "check with In using tuple syntax" do
      valid_status =
        pred do
          check :status, {In, values: [:active, :pending]}
        end

      assert valid_status.(%{status: :active})
      assert valid_status.(%{status: :pending})
      refute valid_status.(%{status: :cancelled})
      refute valid_status.(%{})
    end

    test "check with nested path" do
      valid_exposure =
        pred do
          check [:exposure, :water], {In, values: [:dry, :wet, :soaked]}
        end

      assert valid_exposure.(%{exposure: %{water: :wet}})
      assert valid_exposure.(%{exposure: %{water: :soaked}})
      refute valid_exposure.(%{exposure: %{water: :drenched}})
      refute valid_exposure.(%{})
    end

    test "negate check with In" do
      not_special =
        pred do
          negate check :role, {In, values: [:admin, :moderator]}
        end

      assert not_special.(%{role: :user})
      assert not_special.(%{role: :guest})
      refute not_special.(%{role: :admin})
      refute not_special.(%{role: :moderator})
    end

    test "combined with other predicates" do
      valid_user =
        pred do
          check :status, {In, values: [:active, :pending]}
          check(:verified)
        end

      assert valid_user.(%{status: :active, verified: true})
      refute valid_user.(%{status: :cancelled, verified: true})
      refute valid_user.(%{status: :active, verified: false})
    end
  end

  describe "In predicate argument validation" do
    test "raises when :values option is missing" do
      assert_raise KeyError, fn ->
        In.pred([])
      end
    end
  end
end
