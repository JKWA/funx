defmodule Funx.PredicateTest do
  @moduledoc false
  # Comprehensive test suite for the Predicate module
  #
  # Test Organization:
  #   - Predicate combinators (p_and, p_or, p_not)
  #   - List combinators (p_all, p_any, p_none)
  #   - Projection composition (compose_projection)
  #   - Lens projections
  #   - Prism projections
  #   - Traversal projections
  #   - Function projections
  #   - Edge cases and identity

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Funx.Optics.{Lens, Prism, Traversal}
  alias Funx.Predicate

  doctest Funx.Predicate

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule User do
    @moduledoc false
    defstruct [:name, :age, :email, :active, :verified, :role, :ticket, :score]
  end

  defmodule Order do
    @moduledoc false
    defstruct [:id, :total, :status, :items]
  end

  defmodule Product do
    @moduledoc false
    defstruct [:name, :price, :in_stock, :category]
  end

  defmodule Address do
    @moduledoc false
    defstruct [:city, :state]
  end

  defmodule Person do
    @moduledoc false
    defstruct [:name, :address]
  end

  defmodule Payment do
    @moduledoc false
    defstruct [:method]
  end

  defmodule CreditCard do
    @moduledoc false
    defstruct [:number, :expiry]
  end

  defmodule Team do
    @moduledoc false
    defstruct [:member1, :member2]
  end

  defmodule EmptyTeam do
    @moduledoc false
    defstruct [:members]
  end

  # ============================================================================
  # Sample Predicates
  # ============================================================================

  defp adult?(user), do: user.age >= 18
  defp active?(user), do: user.active
  defp verified?(user), do: user.verified

  defp vip?(%User{ticket: :vip}), do: true
  defp vip?(_), do: false

  defp positive?(n), do: n > 0
  defp even?(n), do: rem(n, 2) == 0

  # ============================================================================
  # Binary Predicate Combinators
  # ============================================================================

  describe "p_and/2" do
    test "returns true when both predicates are true" do
      combined = Predicate.p_and(&positive?/1, &even?/1)

      assert combined.(4)
      assert combined.(2)
      refute combined.(1)
      refute combined.(-2)
    end

    test "returns false when first predicate is false" do
      combined = Predicate.p_and(&positive?/1, &even?/1)

      refute combined.(-2)
    end

    test "returns false when second predicate is false" do
      combined = Predicate.p_and(&positive?/1, &even?/1)

      refute combined.(3)
    end

    test "works with user predicates" do
      can_enter = Predicate.p_and(&adult?/1, &vip?/1)

      assert can_enter.(%User{age: 20, ticket: :vip})
      refute can_enter.(%User{age: 20, ticket: :basic})
      refute can_enter.(%User{age: 17, ticket: :vip})
    end

    test "is associative" do
      pred1 = &positive?/1
      pred2 = &even?/1
      pred3 = fn n -> n < 10 end

      # (pred1 AND pred2) AND pred3
      left_assoc = Predicate.p_and(Predicate.p_and(pred1, pred2), pred3)
      # pred1 AND (pred2 AND pred3)
      right_assoc = Predicate.p_and(pred1, Predicate.p_and(pred2, pred3))

      assert left_assoc.(4) == right_assoc.(4)
      assert left_assoc.(12) == right_assoc.(12)
    end
  end

  describe "p_or/2" do
    test "returns true when either predicate is true" do
      combined = Predicate.p_or(&positive?/1, &even?/1)

      assert combined.(4)
      assert combined.(1)
      assert combined.(-2)
      refute combined.(-1)
    end

    test "returns true when only first predicate is true" do
      combined = Predicate.p_or(&positive?/1, &even?/1)

      assert combined.(3)
    end

    test "returns true when only second predicate is true" do
      combined = Predicate.p_or(&positive?/1, &even?/1)

      assert combined.(-2)
    end

    test "works with user predicates" do
      can_enter = Predicate.p_or(&adult?/1, &vip?/1)

      assert can_enter.(%User{age: 20, ticket: :vip})
      assert can_enter.(%User{age: 20, ticket: :basic})
      assert can_enter.(%User{age: 17, ticket: :vip})
      refute can_enter.(%User{age: 17, ticket: :basic})
    end

    test "is associative" do
      pred1 = &positive?/1
      pred2 = &even?/1
      pred3 = fn n -> n < 10 end

      # (pred1 OR pred2) OR pred3
      left_assoc = Predicate.p_or(Predicate.p_or(pred1, pred2), pred3)
      # pred1 OR (pred2 OR pred3)
      right_assoc = Predicate.p_or(pred1, Predicate.p_or(pred2, pred3))

      assert left_assoc.(15) == right_assoc.(15)
      assert left_assoc.(-5) == right_assoc.(-5)
    end
  end

  describe "p_not/1" do
    test "negates a predicate" do
      negated = Predicate.p_not(&positive?/1)

      assert negated.(0)
      assert negated.(-1)
      refute negated.(1)
    end

    test "double negation returns original" do
      original = &positive?/1
      double_negated = Predicate.p_not(Predicate.p_not(original))

      assert double_negated.(5) == original.(5)
      assert double_negated.(-5) == original.(-5)
    end

    test "works with user predicates" do
      not_adult = Predicate.p_not(&adult?/1)

      assert not_adult.(%User{age: 16})
      refute not_adult.(%User{age: 20})
    end
  end

  # ============================================================================
  # List Predicate Combinators
  # ============================================================================

  describe "p_all/1" do
    test "combines list of predicates using AND" do
      can_enter = Predicate.p_all([&adult?/1, &active?/1, &verified?/1])

      assert can_enter.(%User{age: 20, active: true, verified: true})
      refute can_enter.(%User{age: 20, active: true, verified: false})
      refute can_enter.(%User{age: 17, active: true, verified: true})
    end

    test "works with single predicate" do
      can_enter = Predicate.p_all([&vip?/1])

      assert can_enter.(%User{ticket: :vip})
      refute can_enter.(%User{ticket: :basic})
    end

    test "empty list returns true (identity)" do
      always_true = Predicate.p_all([])

      assert always_true.(%User{age: 20})
      assert always_true.(%User{age: 16})
      assert always_true.(42)
    end

    test "short-circuits on first false" do
      # This test demonstrates that p_all evaluates predicates in order
      predicates = [
        fn _ -> false end,
        fn _ -> raise "Should not be called" end
      ]

      combined = Predicate.p_all(predicates)
      refute combined.(42)
    end

    test "works with numeric predicates" do
      in_range = Predicate.p_all([&positive?/1, &even?/1, fn n -> n < 10 end])

      assert in_range.(4)
      refute in_range.(12)
      refute in_range.(3)
    end
  end

  describe "p_any/1" do
    test "combines list of predicates using OR" do
      can_enter = Predicate.p_any([&adult?/1, &vip?/1, &verified?/1])

      assert can_enter.(%User{age: 20, ticket: :basic, verified: false})
      assert can_enter.(%User{age: 16, ticket: :vip, verified: false})
      assert can_enter.(%User{age: 16, ticket: :basic, verified: true})
      refute can_enter.(%User{age: 16, ticket: :basic, verified: false})
    end

    test "works with single predicate" do
      can_enter = Predicate.p_any([&vip?/1])

      assert can_enter.(%User{ticket: :vip})
      refute can_enter.(%User{ticket: :basic})
    end

    test "empty list returns false (identity)" do
      always_false = Predicate.p_any([])

      refute always_false.(%User{age: 20})
      refute always_false.(%User{age: 16})
      refute always_false.(42)
    end

    test "short-circuits on first true" do
      # This test demonstrates that p_any evaluates predicates in order
      predicates = [
        fn _ -> true end,
        fn _ -> raise "Should not be called" end
      ]

      combined = Predicate.p_any(predicates)
      assert combined.(42)
    end

    test "works with numeric predicates" do
      interesting = Predicate.p_any([&positive?/1, &even?/1])

      assert interesting.(5)
      assert interesting.(-2)
      refute interesting.(-3)
    end
  end

  describe "p_none/1" do
    test "returns true when none of the predicates are true" do
      cannot_enter = Predicate.p_none([&adult?/1, &vip?/1])

      refute cannot_enter.(%User{age: 20, ticket: :vip})
      refute cannot_enter.(%User{age: 20, ticket: :basic})
      refute cannot_enter.(%User{age: 16, ticket: :vip})
      assert cannot_enter.(%User{age: 16, ticket: :basic})
    end

    test "works with single predicate" do
      not_vip = Predicate.p_none([&vip?/1])

      refute not_vip.(%User{ticket: :vip})
      assert not_vip.(%User{ticket: :basic})
    end

    test "empty list returns true" do
      always_true = Predicate.p_none([])

      assert always_true.(%User{age: 20})
      assert always_true.(%User{age: 16})
      assert always_true.(42)
    end

    test "equivalent to negating p_any" do
      predicates = [&adult?/1, &vip?/1]

      p_none_result = Predicate.p_none(predicates)
      negated_p_any = Predicate.p_not(Predicate.p_any(predicates))

      user1 = %User{age: 20, ticket: :basic}
      user2 = %User{age: 16, ticket: :basic}

      assert p_none_result.(user1) == negated_p_any.(user1)
      assert p_none_result.(user2) == negated_p_any.(user2)
    end

    test "works with numeric predicates" do
      not_special = Predicate.p_none([&positive?/1, &even?/1])

      assert not_special.(-3)
      refute not_special.(5)
      refute not_special.(-2)
    end
  end

  # ============================================================================
  # Projection Composition
  # ============================================================================

  describe "compose_projection/2 with Lens" do
    test "composes lens with predicate" do
      check_adult = Predicate.compose_projection(Lens.key(:age), &(&1 >= 18))

      assert check_adult.(%User{age: 20})
      refute check_adult.(%User{age: 16})
    end

    test "works with nested lens path" do
      check_texas =
        Predicate.compose_projection(
          Lens.path([:address, :state]),
          &(&1 == "TX")
        )

      assert check_texas.(%Person{address: %Address{state: "TX"}})
      refute check_texas.(%Person{address: %Address{state: "CA"}})
    end

    test "composes with complex predicates" do
      check_high_score =
        Predicate.compose_projection(
          Lens.key(:score),
          fn score -> score >= 90 and score <= 100 end
        )

      assert check_high_score.(%User{score: 95})
      refute check_high_score.(%User{score: 85})
    end
  end

  describe "compose_projection/2 with Prism" do
    test "composes prism with predicate" do
      check_long_name =
        Predicate.compose_projection(
          Prism.key(:name),
          fn name -> String.length(name) > 5 end
        )

      assert check_long_name.(%User{name: "Alexander"})
      refute check_long_name.(%User{name: "Joe"})
    end

    test "returns false when prism returns Nothing" do
      check_long_name =
        Predicate.compose_projection(
          Prism.key(:name),
          fn name -> String.length(name) > 5 end
        )

      refute check_long_name.(%User{name: nil})
      refute check_long_name.(%{})
    end

    test "handles Just values correctly" do
      check_active_role =
        Predicate.compose_projection(
          Prism.key(:role),
          fn role -> role in [:admin, :moderator] end
        )

      assert check_active_role.(%User{role: :admin})
      assert check_active_role.(%User{role: :moderator})
      refute check_active_role.(%User{role: :user})
    end

    test "works with prism path" do
      check_valid_expiry =
        Predicate.compose_projection(
          Prism.path([{Payment, :method}, {CreditCard, :expiry}]),
          fn expiry -> expiry > "2025-01" end
        )

      assert check_valid_expiry.(%Payment{method: %CreditCard{expiry: "2026-12"}})
      refute check_valid_expiry.(%Payment{method: %CreditCard{expiry: "2024-01"}})
      refute check_valid_expiry.(%Payment{method: :cash})
    end
  end

  describe "compose_projection/2 with Traversal" do
    test "returns true if any focused value matches predicate" do
      traversal = Traversal.combine([Lens.key(:member1), Lens.key(:member2)])

      check_has_adult =
        Predicate.compose_projection(
          traversal,
          fn member -> member.age >= 18 end
        )

      assert check_has_adult.(%Team{
               member1: %User{age: 20},
               member2: %User{age: 16}
             })

      refute check_has_adult.(%Team{
               member1: %User{age: 16},
               member2: %User{age: 17}
             })
    end

    test "works with empty foci" do
      traversal = Traversal.combine([])

      check = Predicate.compose_projection(traversal, fn _ -> true end)

      refute check.(%EmptyTeam{members: []})
    end
  end

  describe "compose_projection/2 projection failure semantics" do
    test "missing projection returns false for all projection types" do
      # This test explicitly documents the contract: projection failure → false
      # regardless of projection type (except Lens, which raises)

      always_true = fn _ -> true end

      # Prism: missing key returns false (graceful)
      prism_check = Predicate.compose_projection(Prism.key(:missing), always_true)
      refute prism_check.(%User{})
      refute prism_check.(%{})

      # Prism: nil value returns false (graceful)
      prism_nil_check = Predicate.compose_projection(Prism.key(:name), always_true)
      refute prism_nil_check.(%User{name: nil})

      # Traversal: empty foci returns false
      empty_traversal = Traversal.combine([])
      traversal_check = Predicate.compose_projection(empty_traversal, always_true)
      refute traversal_check.(%User{})

      # Traversal: all foci fail returns false
      traversal = Traversal.combine([Lens.key(:age)])
      failing_pred = fn _ -> false end
      traversal_fail_check = Predicate.compose_projection(traversal, failing_pred)
      refute traversal_fail_check.(%User{age: 20})

      # Function: custom projection can handle missing data
      safe_function = fn user -> Map.get(user, :missing, :default) end
      function_check = Predicate.compose_projection(safe_function, fn val -> val == :default end)
      assert function_check.(%{})
    end

    test "Lens raises on missing field (total projection contract)" do
      always_true = fn _ -> true end
      lens_check = Predicate.compose_projection(Lens.key(:missing), always_true)

      assert_raise KeyError, fn ->
        lens_check.(%{})
      end
    end

    test "raises ArgumentError for invalid projection" do
      always_true = fn _ -> true end

      # Non-function, non-optic values raise clear errors
      assert_raise ArgumentError, ~r/Expected a 1-arity function for projection/, fn ->
        Predicate.compose_projection(:not_a_projection, always_true)
      end

      assert_raise ArgumentError, ~r/Expected a 1-arity function for projection/, fn ->
        Predicate.compose_projection("not a projection", always_true)
      end

      assert_raise ArgumentError, ~r/Expected a 1-arity function for projection/, fn ->
        Predicate.compose_projection(42, always_true)
      end

      # Wrong arity function raises clear error
      assert_raise ArgumentError, ~r/Expected a 1-arity function for projection/, fn ->
        Predicate.compose_projection(fn -> :no_args end, always_true)
      end

      assert_raise ArgumentError, ~r/Expected a 1-arity function for projection/, fn ->
        Predicate.compose_projection(fn _x, _y -> :two_args end, always_true)
      end
    end
  end

  describe "compose_projection/2 with Function" do
    test "composes function with predicate" do
      check_gmail =
        Predicate.compose_projection(
          & &1.email,
          fn email -> String.ends_with?(email, "@gmail.com") end
        )

      assert check_gmail.(%User{email: "user@gmail.com"})
      refute check_gmail.(%User{email: "user@yahoo.com"})
    end

    test "works with anonymous function" do
      check_discounted =
        Predicate.compose_projection(
          fn order -> order.total * 0.9 end,
          fn discounted_total -> discounted_total < 100 end
        )

      assert check_discounted.(%Order{total: 100})
      refute check_discounted.(%Order{total: 120})
    end

    test "composes with identity function" do
      check_positive = Predicate.compose_projection(&Function.identity/1, &positive?/1)

      assert check_positive.(5)
      refute check_positive.(-5)
    end
  end

  # ============================================================================
  # Complex Compositions
  # ============================================================================

  describe "complex predicate compositions" do
    test "combines p_and with compose_projection" do
      check_eligible =
        Predicate.p_and(
          Predicate.compose_projection(Lens.key(:age), &(&1 >= 18)),
          Predicate.compose_projection(Lens.key(:active), &(&1 == true))
        )

      assert check_eligible.(%User{age: 20, active: true})
      refute check_eligible.(%User{age: 20, active: false})
      refute check_eligible.(%User{age: 16, active: true})
    end

    test "nests p_all within p_any" do
      # (adult AND verified) OR vip
      check_special =
        Predicate.p_any([
          Predicate.p_all([&adult?/1, &verified?/1]),
          &vip?/1
        ])

      assert check_special.(%User{age: 20, verified: true, ticket: :basic})
      assert check_special.(%User{age: 16, verified: false, ticket: :vip})
      refute check_special.(%User{age: 16, verified: true, ticket: :basic})
    end

    test "composes multiple projections with p_all" do
      check_valid_order =
        Predicate.p_all([
          Predicate.compose_projection(Lens.key(:total), &(&1 > 0)),
          Predicate.compose_projection(Lens.key(:status), &(&1 == :pending)),
          Predicate.compose_projection(Lens.key(:items), &(&1 > 0))
        ])

      assert check_valid_order.(%Order{total: 100, status: :pending, items: 5})
      refute check_valid_order.(%Order{total: 0, status: :pending, items: 5})
      refute check_valid_order.(%Order{total: 100, status: :completed, items: 5})
    end
  end

  # ============================================================================
  # Edge Cases and Identity
  # ============================================================================

  describe "edge cases" do
    test "predicate works with any data type" do
      check = Predicate.p_and(fn _ -> true end, fn _ -> true end)

      assert check.("string")
      assert check.(42)
      assert check.([1, 2, 3])
      assert check.(%{key: :value})
    end

    test "predicates are composable" do
      pred1 = Predicate.p_and(&positive?/1, &even?/1)
      pred2 = Predicate.p_and(pred1, fn n -> n < 10 end)

      assert pred2.(4)
      refute pred2.(12)
    end

    test "p_all with nested p_any" do
      check =
        Predicate.p_all([
          &active?/1,
          Predicate.p_any([&adult?/1, &vip?/1])
        ])

      assert check.(%User{active: true, age: 20, ticket: :basic})
      assert check.(%User{active: true, age: 16, ticket: :vip})
      refute check.(%User{active: false, age: 20, ticket: :basic})
    end
  end

  describe "monoid properties" do
    test "p_all identity is always true" do
      identity = Predicate.p_all([])

      assert identity.(42)
      assert identity.("anything")
    end

    test "p_any identity is always false" do
      identity = Predicate.p_any([])

      refute identity.(42)
      refute identity.("anything")
    end

    test "p_all is associative" do
      predicates = [&positive?/1, &even?/1, fn n -> n < 10 end]

      # Different groupings should produce same result
      left = Predicate.p_all([Predicate.p_all(Enum.take(predicates, 2)), Enum.at(predicates, 2)])

      right =
        Predicate.p_all([
          Enum.at(predicates, 0),
          Predicate.p_all(Enum.drop(predicates, 1))
        ])

      flat = Predicate.p_all(predicates)

      assert left.(4) == right.(4)
      assert left.(4) == flat.(4)
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: boolean algebra laws" do
    property "p_and is commutative: p_and(a, b) == p_and(b, a)" do
      check all(
              x <- integer(),
              threshold1 <- integer(),
              threshold2 <- integer()
            ) do
        pred1 = fn n -> n > threshold1 end
        pred2 = fn n -> n > threshold2 end

        ab = Predicate.p_and(pred1, pred2)
        ba = Predicate.p_and(pred2, pred1)

        assert ab.(x) == ba.(x)
      end
    end

    property "p_or is commutative: p_or(a, b) == p_or(b, a)" do
      check all(
              x <- integer(),
              threshold1 <- integer(),
              threshold2 <- integer()
            ) do
        pred1 = fn n -> n > threshold1 end
        pred2 = fn n -> n > threshold2 end

        ab = Predicate.p_or(pred1, pred2)
        ba = Predicate.p_or(pred2, pred1)

        assert ab.(x) == ba.(x)
      end
    end

    property "p_and is associative: p_and(p_and(a, b), c) == p_and(a, p_and(b, c))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer(),
              t3 <- integer()
            ) do
        pred1 = fn n -> n > t1 end
        pred2 = fn n -> n > t2 end
        pred3 = fn n -> n > t3 end

        left = Predicate.p_and(Predicate.p_and(pred1, pred2), pred3)
        right = Predicate.p_and(pred1, Predicate.p_and(pred2, pred3))

        assert left.(x) == right.(x)
      end
    end

    property "p_or is associative: p_or(p_or(a, b), c) == p_or(a, p_or(b, c))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer(),
              t3 <- integer()
            ) do
        pred1 = fn n -> n > t1 end
        pred2 = fn n -> n > t2 end
        pred3 = fn n -> n > t3 end

        left = Predicate.p_or(Predicate.p_or(pred1, pred2), pred3)
        right = Predicate.p_or(pred1, Predicate.p_or(pred2, pred3))

        assert left.(x) == right.(x)
      end
    end

    property "p_and distributes over p_or: p_and(a, p_or(b, c)) == p_or(p_and(a, b), p_and(a, c))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer(),
              t3 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end
        pred_c = fn n -> n > t3 end

        left = Predicate.p_and(pred_a, Predicate.p_or(pred_b, pred_c))
        right = Predicate.p_or(Predicate.p_and(pred_a, pred_b), Predicate.p_and(pred_a, pred_c))

        assert left.(x) == right.(x)
      end
    end

    property "p_or distributes over p_and: p_or(a, p_and(b, c)) == p_and(p_or(a, b), p_or(a, c))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer(),
              t3 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end
        pred_c = fn n -> n > t3 end

        left = Predicate.p_or(pred_a, Predicate.p_and(pred_b, pred_c))
        right = Predicate.p_and(Predicate.p_or(pred_a, pred_b), Predicate.p_or(pred_a, pred_c))

        assert left.(x) == right.(x)
      end
    end

    property "double negation: p_not(p_not(p)) == p" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        double_negated = Predicate.p_not(Predicate.p_not(pred))

        assert pred.(x) == double_negated.(x)
      end
    end

    property "De Morgan's law 1: p_not(p_and(a, b)) == p_or(p_not(a), p_not(b))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end

        left = Predicate.p_not(Predicate.p_and(pred_a, pred_b))
        right = Predicate.p_or(Predicate.p_not(pred_a), Predicate.p_not(pred_b))

        assert left.(x) == right.(x)
      end
    end

    property "De Morgan's law 2: p_not(p_or(a, b)) == p_and(p_not(a), p_not(b))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end

        left = Predicate.p_not(Predicate.p_or(pred_a, pred_b))
        right = Predicate.p_and(Predicate.p_not(pred_a), Predicate.p_not(pred_b))

        assert left.(x) == right.(x)
      end
    end
  end

  describe "property: identity laws" do
    property "p_and with always-true is identity: p_and(p, always_true) == p" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        always_true = fn _ -> true end

        combined = Predicate.p_and(pred, always_true)

        assert pred.(x) == combined.(x)
      end
    end

    property "p_or with always-false is identity: p_or(p, always_false) == p" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        always_false = fn _ -> false end

        combined = Predicate.p_or(pred, always_false)

        assert pred.(x) == combined.(x)
      end
    end

    property "p_and with always-false is always false" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        always_false = fn _ -> false end

        combined = Predicate.p_and(pred, always_false)

        refute combined.(x)
      end
    end

    property "p_or with always-true is always true" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        always_true = fn _ -> true end

        combined = Predicate.p_or(pred, always_true)

        assert combined.(x)
      end
    end
  end

  describe "property: list combinator laws" do
    property "p_all with empty list is always true" do
      check all(x <- term()) do
        pred = Predicate.p_all([])
        assert pred.(x)
      end
    end

    property "p_any with empty list is always false" do
      check all(x <- term()) do
        pred = Predicate.p_any([])
        refute pred.(x)
      end
    end

    property "p_all with single predicate equals that predicate" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        combined = Predicate.p_all([pred])

        assert pred.(x) == combined.(x)
      end
    end

    property "p_any with single predicate equals that predicate" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        combined = Predicate.p_any([pred])

        assert pred.(x) == combined.(x)
      end
    end

    property "p_none is equivalent to p_not(p_any(...))" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        predicates = [fn n -> n > t1 end, fn n -> n > t2 end]

        p_none_result = Predicate.p_none(predicates)
        negated_p_any = Predicate.p_not(Predicate.p_any(predicates))

        assert p_none_result.(x) == negated_p_any.(x)
      end
    end

    property "p_all flattening: p_all([a, b]) == p_and(a, b)" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred1 = fn n -> n > t1 end
        pred2 = fn n -> n > t2 end

        from_list = Predicate.p_all([pred1, pred2])
        from_and = Predicate.p_and(pred1, pred2)

        assert from_list.(x) == from_and.(x)
      end
    end

    property "p_any flattening: p_any([a, b]) == p_or(a, b)" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred1 = fn n -> n > t1 end
        pred2 = fn n -> n > t2 end

        from_list = Predicate.p_any([pred1, pred2])
        from_or = Predicate.p_or(pred1, pred2)

        assert from_list.(x) == from_or.(x)
      end
    end
  end

  describe "property: compose_projection laws" do
    property "compose_projection preserves predicate semantics with Lens" do
      check all(
              age <- integer(),
              threshold <- integer()
            ) do
        user = %User{age: age}
        pred = fn a -> a > threshold end

        composed = Predicate.compose_projection(Lens.key(:age), pred)

        assert composed.(user) == pred.(age)
      end
    end

    property "compose_projection with identity function equals original predicate" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        composed = Predicate.compose_projection(&Function.identity/1, pred)

        assert pred.(x) == composed.(x)
      end
    end

    property "compose_projection is associative with function composition" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        # f: x -> x * 2
        # g: x -> x + 1
        # p: x -> x > threshold
        f = fn x -> x * 2 end
        g = fn x -> x + 1 end
        pred = fn n -> n > threshold end

        # compose_projection(f, compose_projection(g, p))
        inner = Predicate.compose_projection(g, pred)
        outer = Predicate.compose_projection(f, inner)

        # compose_projection(f ∘ g, p)
        composed_functions = fn x -> g.(f.(x)) end
        direct = Predicate.compose_projection(composed_functions, pred)

        assert outer.(x) == direct.(x)
      end
    end
  end

  describe "property: idempotence" do
    property "p_and is idempotent: p_and(p, p) == p" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        doubled = Predicate.p_and(pred, pred)

        assert pred.(x) == doubled.(x)
      end
    end

    property "p_or is idempotent: p_or(p, p) == p" do
      check all(
              x <- integer(),
              threshold <- integer()
            ) do
        pred = fn n -> n > threshold end
        doubled = Predicate.p_or(pred, pred)

        assert pred.(x) == doubled.(x)
      end
    end
  end

  describe "property: absorption laws" do
    property "p_and absorption: p_and(a, p_or(a, b)) == a" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end

        absorbed = Predicate.p_and(pred_a, Predicate.p_or(pred_a, pred_b))

        assert pred_a.(x) == absorbed.(x)
      end
    end

    property "p_or absorption: p_or(a, p_and(a, b)) == a" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end

        absorbed = Predicate.p_or(pred_a, Predicate.p_and(pred_a, pred_b))

        assert pred_a.(x) == absorbed.(x)
      end
    end
  end
end
