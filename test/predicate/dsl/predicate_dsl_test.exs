defmodule Funx.Predicate.DslTest do
  @moduledoc false
  # Comprehensive test suite for the Predicate DSL
  #
  # Test Organization:
  #   - on directive (projections with optics)
  #   - Bare predicates (simple predicate functions)
  #   - Multiple predicates (implicit AND logic)
  #   - negate directive (negated predicates)
  #   - all blocks (explicit AND logic)
  #   - any blocks (OR logic)
  #   - Deep nesting (complex compositions)
  #   - Different predicate forms (captured, anonymous, named)
  #   - Helper function projections (0-arity helpers)
  #   - Behaviour modules (custom predicate logic)
  #   - Empty blocks (error cases)
  #   - Compile-time error handling

  use ExUnit.Case, async: true
  use Funx.Predicate
  use ExUnitProperties

  alias Funx.Optics.{Lens, Prism, Traversal}

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule User do
    defstruct [:name, :age, :email, :role, :active, :verified, :banned, :suspended]
  end

  defmodule Order do
    defstruct [:id, :total, :status, :items]
  end

  defmodule Product do
    defstruct [:name, :price, :in_stock, :category]
  end

  # Sum type for Order status (demonstrates Prism branch selection)
  defmodule OrderStatus.Pending do
    defstruct []
  end

  defmodule OrderStatus.Completed do
    defstruct [:total, :completed_at]
  end

  defmodule OrderStatus.Cancelled do
    defstruct [:reason]
  end

  # Transaction for Traversal examples (relating multiple foci)
  defmodule Transaction do
    defstruct [:charge_amount, :refund_amount, :status]
  end

  # ============================================================================
  # Custom Behaviour Modules
  # ============================================================================
  # Behaviours return predicates for reusable validation logic

  defmodule IsActive do
    @moduledoc false
    # Checks if a user is active
    @behaviour Funx.Predicate.Dsl.Behaviour

    @impl true
    def pred(_opts) do
      fn user -> user.active end
    end
  end

  defmodule HasMinimumAge do
    @moduledoc false
    # Checks age with configurable minimum
    @behaviour Funx.Predicate.Dsl.Behaviour

    @impl true
    def pred(opts) do
      minimum = Keyword.get(opts, :minimum, 18)
      fn user -> user.age >= minimum end
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================
  # 0-arity helper functions for testing projection composition

  defmodule PredicateHelpers do
    @moduledoc false
    # Helpers that return predicates

    def adult?, do: fn user -> user.age >= 18 end
    def verified?, do: fn user -> user.verified end
  end

  defmodule OpticHelpers do
    @moduledoc false
    # Helpers that return optics (projections)
    alias Funx.Optics.{Lens, Prism, Traversal}

    def age_lens, do: Lens.key(:age)
    def name_prism, do: Prism.key(:name)

    def amounts_traversal do
      # Traversal for relating charge and refund amounts
      Traversal.combine([Lens.key(:charge_amount), Lens.key(:refund_amount)])
    end
  end

  # ============================================================================
  # Sample Predicates
  # ============================================================================
  # Named predicates for testing

  defp adult?(person), do: person.age >= 18
  defp has_ticket(person), do: person.tickets > 0
  defp vip?(person), do: person.vip
  defp sponsor?(person), do: person.sponsor
  defp banned?(person), do: person.banned
  defp verified?(person), do: person.verified
  defp admin?(person), do: person.role == :admin
  defp moderator?(person), do: person.role == :moderator
  defp has_permission(person), do: person.has_permission
  defp suspended?(person), do: person.suspended

  # ============================================================================
  # Common Test Fixtures
  # ============================================================================

  setup do
    %{
      # Standard test users with various attributes
      adult_active: %{
        age: 30,
        verified: true,
        active: true,
        role: :user,
        vip: false,
        sponsor: false,
        banned: false
      },
      minor_active: %{
        age: 16,
        verified: false,
        active: true,
        role: :user,
        vip: false,
        sponsor: false,
        banned: false
      },
      admin_user: %{
        age: 25,
        verified: true,
        active: true,
        role: :admin,
        vip: false,
        sponsor: false,
        banned: false
      },
      vip_user: %{
        age: 35,
        verified: true,
        active: true,
        role: :user,
        vip: true,
        sponsor: false,
        banned: false
      },
      inactive_user: %{
        age: 28,
        verified: true,
        active: false,
        role: :user,
        vip: false,
        sponsor: false,
        banned: false
      },
      banned_user: %{
        age: 22,
        verified: false,
        active: false,
        role: :user,
        vip: false,
        sponsor: false,
        banned: true
      },

      # Simple maps for specific tests
      has_name: %{name: "Alexander"},
      short_name: %{name: "Joe"},
      no_name: %{},
      high_score: %{score: 150},
      low_score: %{score: 50},

      # Age-specific maps
      age_20: %{age: 20},
      age_16: %{age: 16},
      age_empty: %{}
    }
  end

  # ============================================================================
  # on Directive Tests
  # ============================================================================

  describe "check directive (projections)" do
    test "check with atom field", %{age_20: age_20, age_16: age_16, age_empty: age_empty} do
      age_check =
        pred do
          check(:age, fn age -> age >= 18 end)
        end

      assert age_check.(age_20)
      refute age_check.(age_16)
      refute age_check.(age_empty)
    end

    test "check with Prism.key (degenerate sum: present | absent)", %{
      has_name: has_name,
      short_name: short_name,
      no_name: no_name
    } do
      name_length_check =
        pred do
          check(Prism.key(:name), fn name -> String.length(name) > 3 end)
        end

      assert name_length_check.(has_name)
      refute name_length_check.(short_name)
      # absent case
      refute name_length_check.(no_name)
    end

    test "check with Prism.struct (sum type branch selection)" do
      # Only applies to Completed orders (branch selection)
      check_high_value_completed =
        pred do
          check(Prism.path([:status, OrderStatus.Completed]), fn completed ->
            completed.total >= 500
          end)
        end

      completed_order = %Order{
        id: 1,
        status: %OrderStatus.Completed{total: 600, completed_at: ~U[2024-01-01 00:00:00Z]}
      }

      pending_order = %Order{id: 2, status: %OrderStatus.Pending{}}
      cancelled_order = %Order{id: 3, status: %OrderStatus.Cancelled{reason: "Stock"}}

      # matches branch AND predicate
      assert check_high_value_completed.(completed_order)
      # branch doesn't match
      refute check_high_value_completed.(pending_order)
      # branch doesn't match
      refute check_high_value_completed.(cancelled_order)
    end

    test "check with Lens.key", %{high_score: high_score, low_score: low_score} do
      score_check =
        pred do
          check(Lens.key(:score), fn score -> score > 100 end)
        end

      assert score_check.(high_score)
      refute score_check.(low_score)
    end

    test "on with captured function projection" do
      check =
        pred do
          check(&Map.get(&1, :age), fn age -> age >= 21 end)
        end

      assert check.(%{age: 25})
      refute check.(%{age: 18})
    end

    test "on with anonymous function projection" do
      check =
        pred do
          check(fn person -> person.age end, fn age -> age >= 18 end)
        end

      assert check.(%{age: 20})
      refute check.(%{age: 16})
    end

    test "check with variable projection (runtime optic)" do
      # Variable bound to optic at runtime
      my_lens = Lens.key(:score)

      check =
        pred do
          check(my_lens, fn score -> score > 100 end)
        end

      assert check.(%{score: 150})
      refute check.(%{score: 50})
    end

    test "check with Traversal (relating multiple foci)" do
      # Traversal collects foci so predicate can relate them to each other
      check_matching_amounts =
        pred do
          check(
            Traversal.combine([Lens.key(:charge_amount), Lens.key(:refund_amount)]),
            fn amounts ->
              case amounts do
                [charge, refund] -> charge == refund
                _ -> false
              end
            end
          )
        end

      # Amounts match - valid refund
      assert check_matching_amounts.(%Transaction{
               charge_amount: 100,
               refund_amount: 100,
               status: :refunded
             })

      # Amounts don't match - invalid refund
      refute check_matching_amounts.(%Transaction{
               charge_amount: 100,
               refund_amount: 50,
               status: :refunded
             })

      refute check_matching_amounts.(%Transaction{
               charge_amount: 200,
               refund_amount: 100,
               status: :refunded
             })
    end

    test "on with multiple projections" do
      check =
        pred do
          check(:age, fn age -> age >= 18 end)
          check(:score, fn score -> score > 50 end)
        end

      assert check.(%{age: 20, score: 75})
      refute check.(%{age: 16, score: 75})
      refute check.(%{age: 20, score: 25})
    end

    test "check with list path (nested keys)" do
      nested_data = %{user: %{profile: %{age: 25}}}
      no_profile = %{user: %{}}
      no_user = %{}

      age_check =
        pred do
          check([:user, :profile, :age], fn age -> age >= 18 end)
        end

      assert age_check.(nested_data)
      # Missing keys fail (Prism.path returns nil for missing paths)
      refute age_check.(no_profile)
      refute age_check.(no_user)
    end

    test "check with list path containing struct (struct-aware path)" do
      user = %User{name: "Alice", age: 30}
      nested_data = %{user: user}
      no_user = %{}

      name_check =
        pred do
          check([User, :name], fn name -> String.length(name) > 3 end)
        end

      # Works with struct projection
      assert name_check.(user)

      # Works with nested struct
      nested_name_check =
        pred do
          check([:user, User, :name], fn name -> String.length(name) > 3 end)
        end

      assert nested_name_check.(nested_data)
      # Missing keys fail
      refute nested_name_check.(no_user)
    end

    test "check with list path (short names)" do
      nested_data = %{user: %{profile: %{name: "Jo"}}}

      name_check =
        pred do
          check([:user, :profile, :name], fn name -> String.length(name) > 3 end)
        end

      refute name_check.(nested_data)
    end
  end

  # ============================================================================
  # Default Truthy Check Tests
  # ============================================================================

  describe "check with default truthy predicate" do
    test "single-argument check defaults to truthy" do
      is_active =
        pred do
          check(:active)
        end

      assert is_active.(%{active: true})
      assert is_active.(%{active: 1})
      assert is_active.(%{active: "yes"})
      refute is_active.(%{active: false})
      refute is_active.(%{active: nil})
      refute is_active.(%{})
    end

    test "single-argument check with nested path" do
      is_poisoned =
        pred do
          check([:poison, :active])
        end

      assert is_poisoned.(%{poison: %{active: true}})
      assert is_poisoned.(%{poison: %{active: 1}})
      refute is_poisoned.(%{poison: %{active: false}})
      refute is_poisoned.(%{poison: %{active: nil}})
      refute is_poisoned.(%{poison: %{}})
      refute is_poisoned.(%{})
    end

    test "negate single-argument check" do
      not_active =
        pred do
          negate check(:active)
        end

      assert not_active.(%{active: false})
      assert not_active.(%{active: nil})
      assert not_active.(%{})
      refute not_active.(%{active: true})
      refute not_active.(%{active: 1})
    end

    test "multiple single-argument checks" do
      all_flags =
        pred do
          check(:active)
          check(:verified)
          check(:approved)
        end

      assert all_flags.(%{active: true, verified: true, approved: true})
      refute all_flags.(%{active: true, verified: false, approved: true})
      refute all_flags.(%{active: true, verified: true, approved: nil})
    end

    test "mixed single and two-argument checks" do
      valid_user =
        pred do
          check(:active)
          check :age, fn age -> age >= 18 end
        end

      assert valid_user.(%{active: true, age: 20})
      refute valid_user.(%{active: false, age: 20})
      refute valid_user.(%{active: true, age: 16})
    end
  end

  # ============================================================================
  # Helper Function Tests
  # ============================================================================

  describe "helper functions" do
    test "0-arity helper returning Prism" do
      check =
        pred do
          check(OpticHelpers.name_prism(), fn name -> String.length(name) > 5 end)
        end

      assert check.(%{name: "Alexander"})
      refute check.(%{name: "Joe"})
    end

    test "0-arity helper returning Lens" do
      check =
        pred do
          check(OpticHelpers.age_lens(), fn age -> age >= 21 end)
        end

      assert check.(%{age: 25})
      refute check.(%{age: 18})
    end

    test "0-arity helper returning Traversal (relating foci)" do
      check =
        pred do
          check(OpticHelpers.amounts_traversal(), fn amounts ->
            case amounts do
              [charge, refund] -> charge == refund
              _ -> false
            end
          end)
        end

      assert check.(%Transaction{charge_amount: 100, refund_amount: 100, status: :refunded})
      refute check.(%Transaction{charge_amount: 100, refund_amount: 50, status: :refunded})
    end

    test "0-arity helper returning predicate" do
      check =
        pred do
          PredicateHelpers.adult?()
        end

      assert check.(%{age: 20})
      refute check.(%{age: 16})
    end
  end

  # ============================================================================
  # Behaviour Module Tests
  # ============================================================================

  describe "behaviour modules" do
    test "simple behaviour without options" do
      check =
        pred do
          IsActive
        end

      assert check.(%User{active: true})
      refute check.(%User{active: false})
    end

    test "behaviour with options" do
      check_21 =
        pred do
          {HasMinimumAge, minimum: 21}
        end

      check_18 =
        pred do
          {HasMinimumAge, minimum: 18}
        end

      assert check_21.(%User{age: 25})
      refute check_21.(%User{age: 19})

      assert check_18.(%User{age: 19})
      refute check_18.(%User{age: 16})
    end

    test "behaviour combined with other predicates" do
      check =
        pred do
          IsActive
          check(:age, fn age -> age >= 18 end)
        end

      assert check.(%User{active: true, age: 20})
      refute check.(%User{active: false, age: 20})
      refute check.(%User{active: true, age: 16})
    end

    # Note: Bare module references that don't implement the behaviour are treated
    # as regular predicates (fall through to bare predicate handling), so they don't error.
    test "rejects bare module without behaviour at compile time" do
      # Bare module references without pred/1 are now compile errors

      defmodule NonBehaviourCallable do
        # Module without pred/1
        def some_function(user), do: user.age >= 18
      end

      # Should raise CompileError, not BadFunctionError at runtime
      assert_raise CompileError,
                   ~r/Bare module reference.*does not implement Predicate.Dsl.Behaviour/,
                   fn ->
                     Code.eval_quoted(
                       quote do
                         use Funx.Predicate

                         pred do
                           NonBehaviourCallable
                         end
                       end
                     )
                   end
    end

    test "rejects module without behaviour when using tuple syntax" do
      defmodule NotABehaviour do
        def some_function, do: :ok
      end

      assert_raise CompileError, ~r/does not implement the Predicate.Dsl.Behaviour/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              {NotABehaviour, opt: :value}
            end
          end
        )
      end
    end
  end

  # ============================================================================
  # Bare Predicate Tests
  # ============================================================================

  describe "bare predicates" do
    test "single predicate" do
      check_adult =
        pred do
          &adult?/1
        end

      assert check_adult.(%{age: 20})
      refute check_adult.(%{age: 16})
    end

    test "single predicate with variable reference" do
      adult_var = &adult?/1

      check_adult =
        pred do
          adult_var
        end

      assert check_adult.(%{age: 20})
      refute check_adult.(%{age: 16})
    end

    test "single anonymous function" do
      check_adult =
        pred do
          fn person -> person.age >= 18 end
        end

      assert check_adult.(%{age: 20})
      refute check_adult.(%{age: 16})
    end
  end

  # ============================================================================
  # Multiple Predicates (Implicit AND)
  # ============================================================================

  describe "multiple predicates (implicit all)" do
    test "two predicates" do
      can_enter =
        pred do
          &adult?/1
          &has_ticket/1
        end

      assert can_enter.(%{age: 20, tickets: 1})
      refute can_enter.(%{age: 16, tickets: 1})
      refute can_enter.(%{age: 20, tickets: 0})
    end

    test "three predicates" do
      can_enter_vip =
        pred do
          &adult?/1
          &has_ticket/1
          &vip?/1
        end

      assert can_enter_vip.(%{age: 20, tickets: 1, vip: true})
      refute can_enter_vip.(%{age: 20, tickets: 1, vip: false})
    end
  end

  # ============================================================================
  # negate Directive Tests
  # ============================================================================

  describe "negate directive" do
    test "single negated predicate" do
      not_banned =
        pred do
          negate(&banned?/1)
        end

      assert not_banned.(%{banned: false})
      refute not_banned.(%{banned: true})
    end

    test "mixed predicates with negation" do
      can_enter =
        pred do
          &adult?/1
          &has_ticket/1
          negate(&banned?/1)
        end

      assert can_enter.(%{age: 20, tickets: 1, banned: false})
      refute can_enter.(%{age: 20, tickets: 1, banned: true})
    end

    test "multiple negations" do
      safe_user =
        pred do
          negate(&banned?/1)
          negate(&suspended?/1)
        end

      assert safe_user.(%{banned: false, suspended: false})
      refute safe_user.(%{banned: true, suspended: false})
      refute safe_user.(%{banned: false, suspended: true})
    end
  end

  # ============================================================================
  # negate check Tests (Negated Projections)
  # ============================================================================

  describe "negate check directive" do
    test "negate check with atom field (degenerate sum)" do
      not_long_name =
        pred do
          negate(check(:name, fn name -> String.length(name) > 5 end))
        end

      assert not_long_name.(%{name: "Joe"})
      refute not_long_name.(%{name: "Alexander"})
      # Absent case passes negation (degenerate sum: present | absent)
      assert not_long_name.(%{})
    end

    test "negate check with Prism.key (degenerate sum)" do
      not_adult =
        pred do
          negate(check(Prism.key(:age), fn age -> age >= 18 end))
        end

      assert not_adult.(%{age: 16})
      refute not_adult.(%{age: 20})
      # Absent case passes negation
      assert not_adult.(%{})
    end

    test "negate check with Lens.key" do
      low_score =
        pred do
          negate(check(Lens.key(:score), fn score -> score > 100 end))
        end

      assert low_score.(%{score: 50})
      refute low_score.(%{score: 150})
    end

    test "negate check with function projection" do
      not_verified =
        pred do
          negate(check(fn user -> user.verified end, fn v -> v == true end))
        end

      assert not_verified.(%{verified: false})
      refute not_verified.(%{verified: true})
    end

    test "negate check with Traversal (relating foci)" do
      amounts_dont_match =
        pred do
          negate(
            check(
              Traversal.combine([Lens.key(:charge_amount), Lens.key(:refund_amount)]),
              fn amounts ->
                case amounts do
                  [charge, refund] -> charge == refund
                  _ -> false
                end
              end
            )
          )
        end

      # Amounts don't match - inner predicate false, negation true
      assert amounts_dont_match.(%Transaction{
               charge_amount: 100,
               refund_amount: 50,
               status: :refunded
             })

      # Amounts match - inner predicate true, negation false
      refute amounts_dont_match.(%Transaction{
               charge_amount: 100,
               refund_amount: 100,
               status: :refunded
             })
    end

    test "multiple negate check directives" do
      safe_user =
        pred do
          negate(check(:banned, fn b -> b == true end))
          negate(check(:suspended, fn s -> s == true end))
        end

      assert safe_user.(%{banned: false, suspended: false})
      refute safe_user.(%{banned: true, suspended: false})
      refute safe_user.(%{banned: false, suspended: true})
    end

    test "mixed check and negate check" do
      valid_user =
        pred do
          check(:age, fn age -> age >= 18 end)
          negate(check(:banned, fn b -> b == true end))
        end

      assert valid_user.(%{age: 20, banned: false})
      refute valid_user.(%{age: 16, banned: false})
      refute valid_user.(%{age: 20, banned: true})
    end

    test "negate check with bare predicates" do
      can_enter =
        pred do
          &adult?/1
          negate(check(:banned, fn b -> b == true end))
        end

      assert can_enter.(%{age: 20, tickets: 1, banned: false})
      refute can_enter.(%{age: 16, tickets: 1, banned: false})
      refute can_enter.(%{age: 20, tickets: 1, banned: true})
    end

    test "negate check within any block" do
      has_access =
        pred do
          any do
            &vip?/1
            negate(check(:suspended, fn s -> s == true end))
          end
        end

      # VIP passes even if suspended
      assert has_access.(%{vip: true, sponsor: false, suspended: true})
      # Not suspended and not VIP passes
      assert has_access.(%{vip: false, sponsor: false, suspended: false})
      # Suspended and not VIP fails
      refute has_access.(%{vip: false, sponsor: false, suspended: true})
    end

    test "negate check within all block" do
      verified_user =
        pred do
          all do
            check(:age, fn age -> age >= 18 end)
            negate(check(:banned, fn b -> b == true end))
          end
        end

      assert verified_user.(%{age: 20, banned: false})
      refute verified_user.(%{age: 16, banned: false})
      refute verified_user.(%{age: 20, banned: true})
    end

    test "negate check with list path" do
      nested_adult = %{user: %{profile: %{age: 25}}}
      nested_minor = %{user: %{profile: %{age: 16}}}
      no_age = %{user: %{profile: %{}}}

      not_adult =
        pred do
          negate(check([:user, :profile, :age], fn age -> age >= 18 end))
        end

      refute not_adult.(nested_adult)
      assert not_adult.(nested_minor)
      # Missing path passes negation (Prism behavior)
      assert not_adult.(no_age)
    end
  end

  # ============================================================================
  # negate all/any Block Tests (De Morgan's Laws)
  # ============================================================================

  describe "negate_all blocks" do
    test "negate_all with two predicates" do
      # negate_all(A, B) = any(not A, not B)
      # Not (adult AND has_ticket) = (not adult) OR (not has_ticket)
      reject_entry =
        pred do
          negate_all do
            &adult?/1
            &has_ticket/1
          end
        end

      # Fails both
      assert reject_entry.(%{age: 16, tickets: 0})
      # Fails adult only
      assert reject_entry.(%{age: 16, tickets: 1})
      # Fails ticket only
      assert reject_entry.(%{age: 20, tickets: 0})
      # Passes both (fails the negation)
      refute reject_entry.(%{age: 20, tickets: 1})
    end

    test "negate_all with three predicates" do
      not_premium =
        pred do
          negate_all do
            &adult?/1
            &verified?/1
            &vip?/1
          end
        end

      # At least one fails
      assert not_premium.(%{age: 16, verified: true, vip: true})
      assert not_premium.(%{age: 20, verified: false, vip: true})
      assert not_premium.(%{age: 20, verified: true, vip: false})
      # All pass (fails the negation)
      refute not_premium.(%{age: 20, verified: true, vip: true})
    end

    test "negate_all with check directives" do
      invalid_user =
        pred do
          negate_all do
            check :age, fn age -> age >= 18 end
            check :verified, fn v -> v == true end
          end
        end

      assert invalid_user.(%{age: 16, verified: true})
      assert invalid_user.(%{age: 20, verified: false})
      refute invalid_user.(%{age: 20, verified: true})
    end
  end

  describe "negate_any blocks" do
    test "negate_any with two predicates" do
      # negate_any(A, B) = all(not A, not B)
      # Not (vip OR sponsor) = (not vip) AND (not sponsor)
      regular_user =
        pred do
          negate_any do
            &vip?/1
            &sponsor?/1
          end
        end

      # Neither vip nor sponsor
      assert regular_user.(%{vip: false, sponsor: false})
      # Is vip (fails)
      refute regular_user.(%{vip: true, sponsor: false})
      # Is sponsor (fails)
      refute regular_user.(%{vip: false, sponsor: true})
      # Both (fails)
      refute regular_user.(%{vip: true, sponsor: true})
    end

    test "negate_any with three predicates" do
      no_special_access =
        pred do
          negate_any do
            &vip?/1
            &sponsor?/1
            &admin?/1
          end
        end

      # None are true
      assert no_special_access.(%{vip: false, sponsor: false, role: :user})
      # At least one is true (fails)
      refute no_special_access.(%{vip: true, sponsor: false, role: :user})
      refute no_special_access.(%{vip: false, sponsor: true, role: :user})
      refute no_special_access.(%{vip: false, sponsor: false, role: :admin})
    end

    test "negate_any with check directives" do
      no_flags =
        pred do
          negate_any do
            check :banned, fn b -> b == true end
            check :suspended, fn s -> s == true end
          end
        end

      assert no_flags.(%{banned: false, suspended: false})
      refute no_flags.(%{banned: true, suspended: false})
      refute no_flags.(%{banned: false, suspended: true})
    end
  end

  describe "negate_all/negate_any nested" do
    test "negate_all within any block" do
      special_or_incomplete =
        pred do
          any do
            &vip?/1

            negate_all do
              &adult?/1
              &verified?/1
            end
          end
        end

      # VIP passes
      assert special_or_incomplete.(%{vip: true, age: 16, verified: false})
      # Not adult passes (fails the all)
      assert special_or_incomplete.(%{vip: false, age: 16, verified: true})
      # Adult and verified, not VIP fails
      refute special_or_incomplete.(%{vip: false, age: 20, verified: true})
    end

    test "negate_any within all block" do
      verified_regular =
        pred do
          all do
            &verified?/1

            negate_any do
              &vip?/1
              &admin?/1
            end
          end
        end

      # Verified and regular user
      assert verified_regular.(%{verified: true, vip: false, role: :user})
      # Not verified fails
      refute verified_regular.(%{verified: false, vip: false, role: :user})
      # VIP fails (passes the any, fails the negation)
      refute verified_regular.(%{verified: true, vip: true, role: :user})
    end

    test "negate_all containing all block (recursive block negation)" do
      # Tests recursive application of De Morgan's Laws on nested blocks
      #
      # Original: NOT (adult AND (verified AND vip))
      # Step 1:   NOT adult OR NOT (verified AND vip)     [De Morgan on outer]
      # Step 2:   NOT adult OR (NOT verified OR NOT vip)  [De Morgan on inner]
      # Result:   Passes if ANY condition fails (at least one NOT is true)
      #
      # This tests that negate_node recursively transforms nested Block structures
      not_premium =
        pred do
          negate_all do
            &adult?/1

            all do
              &verified?/1
              &vip?/1
            end
          end
        end

      # Not adult - passes (first condition fails)
      assert not_premium.(%{age: 16, verified: true, vip: true})
      # Adult but not verified - passes (inner block fails)
      assert not_premium.(%{age: 30, verified: false, vip: true})
      # Adult but not vip - passes (inner block fails)
      assert not_premium.(%{age: 30, verified: true, vip: false})
      # Adult AND verified AND vip - fails (all conditions pass)
      refute not_premium.(%{age: 30, verified: true, vip: true})
    end

    test "negate_any containing any block (recursive block negation)" do
      # Tests recursive De Morgan's transformation with opposite strategy
      #
      # Original: NOT (vip OR (admin OR sponsor))
      # Step 1:   NOT vip AND NOT (admin OR sponsor)     [De Morgan flips OR to AND]
      # Step 2:   NOT vip AND (NOT admin AND NOT sponsor) [De Morgan on inner]
      # Result:   Passes only if ALL conditions fail
      #
      # This tests flip_strategy recursively changes nested blocks
      regular_only =
        pred do
          negate_any do
            &vip?/1

            any do
              &admin?/1
              &sponsor?/1
            end
          end
        end

      # Regular user - passes (all conditions fail)
      assert regular_only.(%{vip: false, role: :user, sponsor: false})
      # VIP - fails (first condition passes)
      refute regular_only.(%{vip: true, role: :user, sponsor: false})
      # Admin - fails (inner block passes)
      refute regular_only.(%{vip: false, role: :admin, sponsor: false})
      # Sponsor - fails (inner block passes)
      refute regular_only.(%{vip: false, role: :user, sponsor: true})
    end

    test "negate_all with negated steps (double negation)" do
      # Tests that negate_node correctly flips Step negate flags
      #
      # Original: NOT (NOT adult AND NOT verified)
      # Step 1:   NOT (NOT adult) OR NOT (NOT verified)  [De Morgan on block]
      # Step 2:   adult OR verified                      [Double negation cancels]
      # Result:   Passes if at least one is true
      #
      # This tests negate_node(%Step{negate: true}) -> %Step{negate: false}
      adult_or_verified =
        pred do
          negate_all do
            negate &adult?/1
            negate &verified?/1
          end
        end

      # Adult only - passes
      assert adult_or_verified.(%{age: 30, verified: false})
      # Verified only - passes
      assert adult_or_verified.(%{age: 16, verified: true})
      # Both - passes
      assert adult_or_verified.(%{age: 30, verified: true})
      # Neither - fails
      refute adult_or_verified.(%{age: 16, verified: false})
    end

    test "deeply nested block negation (3 levels)" do
      # Tests De Morgan's Laws applied recursively through 3 levels of nesting
      #
      # Original: NOT (adult AND (verified OR (vip AND sponsor)))
      # Step 1:   NOT adult OR NOT (verified OR (vip AND sponsor))
      # Step 2:   NOT adult OR (NOT verified AND NOT (vip AND sponsor))
      # Step 3:   NOT adult OR (NOT verified AND (NOT vip OR NOT sponsor))
      # Result:   Passes if adult fails OR (verified fails AND (vip OR sponsor fails))
      #
      # This is a comprehensive test of recursive negate_node through multiple levels
      complex_negation =
        pred do
          negate_all do
            &adult?/1

            any do
              &verified?/1

              all do
                &vip?/1
                &sponsor?/1
              end
            end
          end
        end

      # Not adult - passes (first condition fails, short-circuits)
      assert complex_negation.(%{age: 16, verified: true, vip: true, sponsor: true})
      # Adult but nothing else - passes (inner conditions all fail)
      assert complex_negation.(%{age: 30, verified: false, vip: false, sponsor: false})
      # Adult and verified - fails (both top-level conditions pass)
      refute complex_negation.(%{age: 30, verified: true, vip: false, sponsor: false})
      # Adult and (vip AND sponsor) - fails (both top-level conditions pass)
      refute complex_negation.(%{age: 30, verified: false, vip: true, sponsor: true})
    end

    test "negate_any with check directives containing blocks" do
      # NOT (banned OR (age < 18 OR no email))
      valid_user =
        pred do
          negate_any do
            check :banned, fn b -> b == true end

            any do
              check :age, fn age -> age < 18 end
              negate check :email, fn e -> String.contains?(e, "@") end
            end
          end
        end

      # Valid user - passes
      assert valid_user.(%{banned: false, age: 30, email: "user@test.com"})
      # Banned - fails
      refute valid_user.(%{banned: true, age: 30, email: "user@test.com"})
      # Minor - fails
      refute valid_user.(%{banned: false, age: 16, email: "user@test.com"})
      # No email - fails
      refute valid_user.(%{banned: false, age: 30, email: "invalid"})
    end
  end

  # ============================================================================
  # any Block Tests (OR Logic)
  # ============================================================================

  describe "any blocks (OR logic)" do
    test "simple any block" do
      has_access =
        pred do
          any do
            &vip?/1
            &sponsor?/1
          end
        end

      assert has_access.(%{vip: true, sponsor: false})
      assert has_access.(%{vip: false, sponsor: true})
      assert has_access.(%{vip: true, sponsor: true})
      refute has_access.(%{vip: false, sponsor: false})
    end

    test "any block with multiple conditions" do
      special_user =
        pred do
          any do
            &vip?/1
            &sponsor?/1
            &admin?/1
          end
        end

      assert special_user.(%{vip: false, sponsor: false, role: :admin})
      assert special_user.(%{vip: true, sponsor: false, role: :user})
      refute special_user.(%{vip: false, sponsor: false, role: :user})
    end

    test "mixed with top-level predicates" do
      can_enter =
        pred do
          &adult?/1

          any do
            &vip?/1
            &sponsor?/1
          end
        end

      assert can_enter.(%{age: 20, vip: true, sponsor: false})
      assert can_enter.(%{age: 20, vip: false, sponsor: true})
      refute can_enter.(%{age: 16, vip: true, sponsor: false})
      refute can_enter.(%{age: 20, vip: false, sponsor: false})
    end
  end

  # ============================================================================
  # all Block Tests (Explicit AND)
  # ============================================================================

  describe "all blocks (explicit AND)" do
    test "simple all block" do
      verified_user =
        pred do
          all do
            &adult?/1
            &verified?/1
          end
        end

      assert verified_user.(%{age: 20, verified: true})
      refute verified_user.(%{age: 16, verified: true})
      refute verified_user.(%{age: 20, verified: false})
    end

    test "nested all blocks" do
      admin_user =
        pred do
          all do
            all do
              &adult?/1
              &verified?/1
            end

            &admin?/1
          end
        end

      assert admin_user.(%{age: 20, verified: true, role: :admin})
      refute admin_user.(%{age: 16, verified: true, role: :admin})
    end
  end

  # ============================================================================
  # Deep Nesting Tests
  # ============================================================================

  describe "deep nesting" do
    test "any containing all blocks" do
      can_moderate =
        pred do
          any do
            all do
              &admin?/1
              &verified?/1
            end

            all do
              &moderator?/1
              &has_permission/1
            end
          end
        end

      assert can_moderate.(%{role: :admin, verified: true, has_permission: false})
      assert can_moderate.(%{role: :moderator, verified: false, has_permission: true})
      refute can_moderate.(%{role: :admin, verified: false, has_permission: false})
      refute can_moderate.(%{role: :moderator, verified: false, has_permission: false})
    end

    test "complex nesting with negation" do
      can_access =
        pred do
          any do
            all do
              &admin?/1
              &verified?/1
            end

            all do
              &moderator?/1
              &has_permission/1
            end
          end

          negate(&suspended?/1)
        end

      assert can_access.(%{role: :admin, verified: true, suspended: false, has_permission: false})
      refute can_access.(%{role: :admin, verified: true, suspended: true, has_permission: false})
    end

    test "three levels deep" do
      complex_check =
        pred do
          any do
            all do
              &admin?/1

              any do
                &verified?/1
                &has_permission/1
              end
            end

            &vip?/1
          end
        end

      assert complex_check.(%{role: :admin, verified: true, has_permission: false, vip: false})
      assert complex_check.(%{role: :admin, verified: false, has_permission: true, vip: false})
      assert complex_check.(%{role: :user, verified: false, has_permission: false, vip: true})
      refute complex_check.(%{role: :user, verified: false, has_permission: false, vip: false})
    end
  end

  # ============================================================================
  # Different Predicate Forms
  # ============================================================================

  describe "different predicate forms" do
    test "captured functions" do
      check =
        pred do
          &adult?/1
          &has_ticket/1
        end

      assert check.(%{age: 20, tickets: 1})
    end

    test "anonymous functions" do
      check =
        pred do
          fn p -> p.age >= 18 end
          fn p -> p.tickets > 0 end
        end

      assert check.(%{age: 20, tickets: 1})
    end

    test "mixed forms" do
      adult_var = &adult?/1

      check =
        pred do
          adult_var
          fn p -> p.tickets > 0 end
          &verified?/1
        end

      assert check.(%{age: 20, tickets: 1, verified: true})
    end
  end

  # ============================================================================
  # Empty Predicate
  # ============================================================================

  describe "empty predicate" do
    test "empty pred block returns true" do
      always_true =
        pred do
        end

      assert always_true.(%{})
      assert always_true.("anything")
      assert always_true.(123)
    end
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  describe "edge cases" do
    test "single predicate in any block" do
      check =
        pred do
          any do
            &adult?/1
          end
        end

      assert check.(%{age: 20})
      refute check.(%{age: 16})
    end

    test "single predicate in all block" do
      check =
        pred do
          all do
            &adult?/1
          end
        end

      assert check.(%{age: 20})
      refute check.(%{age: 16})
    end
  end

  # ============================================================================
  # Compilation Tests
  # ============================================================================

  describe "compilation" do
    test "compiles to correct function calls" do
      # This test verifies the DSL compiles to the expected p_all/p_any/p_not calls
      check =
        pred do
          &adult?/1

          any do
            &vip?/1
            &sponsor?/1
          end

          negate(&banned?/1)
        end

      # Equivalent functional version
      check_functional =
        Funx.Predicate.p_all([
          &adult?/1,
          Funx.Predicate.p_any([&vip?/1, &sponsor?/1]),
          Funx.Predicate.p_not(&banned?/1)
        ])

      # Test both produce same results
      person1 = %{age: 20, vip: true, sponsor: false, banned: false}
      person2 = %{age: 20, vip: false, sponsor: false, banned: false}
      person3 = %{age: 20, vip: true, sponsor: false, banned: true}

      assert check.(person1) == check_functional.(person1)
      assert check.(person2) == check_functional.(person2)
      assert check.(person3) == check_functional.(person3)
    end
  end

  # ============================================================================
  # Error Cases
  # ============================================================================

  describe "empty blocks return identity" do
    test "empty any block returns false (OR identity)" do
      empty_any =
        pred do
          any do
          end
        end

      refute empty_any.(:anything)
    end

    test "empty all block returns true (AND identity)" do
      empty_all =
        pred do
          all do
          end
        end

      assert empty_all.(:anything)
    end

    test "empty negate_all returns false (NOT true)" do
      empty_negate_all =
        pred do
          negate_all do
          end
        end

      # negate_all with empty -> any with empty -> false
      refute empty_negate_all.(:anything)
    end

    test "empty negate_any returns true (NOT false)" do
      empty_negate_any =
        pred do
          negate_any do
          end
        end

      # negate_any with empty -> all with empty -> true
      assert empty_negate_any.(:anything)
    end

    test "raises on negate without predicate (empty args)" do
      assert_raise CompileError, ~r/The `negate` directive requires a predicate/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              negate()
            end
          end
        )
      end
    end

    test "raises on negate without predicate (nil args)" do
      assert_raise CompileError, ~r/The `negate` directive requires a predicate/, fn ->
        # Manually construct AST with nil args to trigger the {negate, meta, nil} case
        ast =
          quote do
            use Funx.Predicate

            pred do
              unquote({:negate, [line: 1], nil})
            end
          end

        Code.eval_quoted(ast)
      end
    end

    test "raises compile error on bare module reference without pred/1" do
      assert_raise CompileError,
                   ~r/Bare module reference.*does not implement Predicate.Dsl.Behaviour/,
                   fn ->
                     Code.eval_quoted(
                       quote do
                         defmodule NotABehaviour do
                           def some_function, do: :ok
                         end

                         use Funx.Predicate

                         pred do
                           NotABehaviour
                         end
                       end
                     )
                   end
    end

    test "raises compile error on invalid projection type in check" do
      assert_raise CompileError, ~r/Invalid projection type in `check` directive/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              # String literal is not a valid projection type
              check "invalid", fn _ -> true end
            end
          end
        )
      end
    end

    test "raises compile error on invalid projection type (number)" do
      assert_raise CompileError, ~r/Invalid projection type in `check` directive/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              # Number is not a valid projection type
              check 123, fn _ -> true end
            end
          end
        )
      end
    end

    test "raises compile error on invalid projection type (tuple)" do
      assert_raise CompileError, ~r/Invalid projection type in `check` directive/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              # Tuple is not a valid projection type
              check {:foo, :bar}, fn _ -> true end
            end
          end
        )
      end
    end
  end

  # ============================================================================
  # Property Tests - De Morgan's Laws
  # ============================================================================

  describe "property: De Morgan's Laws in DSL" do
    property "negate_all applies De Morgan's Law 1: NOT (A AND B) = (NOT A) OR (NOT B)" do
      check all(
              x <- integer(),
              threshold_a <- integer(),
              threshold_b <- integer()
            ) do
        # Create two simple predicates
        pred_a = fn n -> n > threshold_a end
        pred_b = fn n -> n > threshold_b end

        # DSL version: negate_all do pred_a; pred_b end
        # Should equal: (NOT pred_a) OR (NOT pred_b)
        dsl_result =
          pred do
            negate_all do
              pred_a
              pred_b
            end
          end

        # Manual De Morgan's transformation
        manual_result =
          pred do
            any do
              negate pred_a
              negate pred_b
            end
          end

        # Both should produce the same result
        assert dsl_result.(x) == manual_result.(x)
      end
    end

    property "negate_any applies De Morgan's Law 2: NOT (A OR B) = (NOT A) AND (NOT B)" do
      check all(
              x <- integer(),
              threshold_a <- integer(),
              threshold_b <- integer()
            ) do
        # Create two simple predicates
        pred_a = fn n -> n > threshold_a end
        pred_b = fn n -> n > threshold_b end

        # DSL version: negate_any do pred_a; pred_b end
        # Should equal: (NOT pred_a) AND (NOT pred_b)
        dsl_result =
          pred do
            negate_any do
              pred_a
              pred_b
            end
          end

        # Manual De Morgan's transformation
        manual_result =
          pred do
            all do
              negate pred_a
              negate pred_b
            end
          end

        # Both should produce the same result
        assert dsl_result.(x) == manual_result.(x)
      end
    end

    property "nested negate_all applies De Morgan's recursively" do
      check all(
              x <- integer(),
              t1 <- integer(),
              t2 <- integer(),
              t3 <- integer()
            ) do
        pred_a = fn n -> n > t1 end
        pred_b = fn n -> n > t2 end
        pred_c = fn n -> n > t3 end

        # DSL: NOT (A AND (B AND C))
        dsl_nested =
          pred do
            negate_all do
              pred_a

              all do
                pred_b
                pred_c
              end
            end
          end

        # Manual: NOT A OR NOT (B AND C) = NOT A OR (NOT B OR NOT C)
        manual_expanded =
          pred do
            any do
              negate pred_a

              any do
                negate pred_b
                negate pred_c
              end
            end
          end

        assert dsl_nested.(x) == manual_expanded.(x)
      end
    end

    property "double negation in negate_all cancels: NOT (NOT A AND NOT B) = A OR B" do
      check all(
              x <- integer(),
              threshold_a <- integer(),
              threshold_b <- integer()
            ) do
        pred_a = fn n -> n > threshold_a end
        pred_b = fn n -> n > threshold_b end

        # DSL: negate_all with negated predicates
        double_neg =
          pred do
            negate_all do
              negate pred_a
              negate pred_b
            end
          end

        # Should equal: A OR B
        simple_or =
          pred do
            any do
              pred_a
              pred_b
            end
          end

        assert double_neg.(x) == simple_or.(x)
      end
    end
  end
end
