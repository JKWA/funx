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

    def scores_traversal do
      Traversal.combine([Lens.key(:score1), Lens.key(:score2)])
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
  # on Directive Tests
  # ============================================================================

  describe "check directive (projections)" do
    test "on with atom field" do
      check =
        pred do
          check(:age, fn age -> age >= 18 end)
        end

      assert check.(%{age: 20})
      refute check.(%{age: 16})
      refute check.(%{})
    end

    test "on with Prism.key" do
      check =
        pred do
          check(Prism.key(:name), fn name -> String.length(name) > 3 end)
        end

      assert check.(%{name: "Alexander"})
      refute check.(%{name: "Joe"})
      refute check.(%{})
    end

    test "on with Lens.key" do
      check =
        pred do
          check(Lens.key(:score), fn score -> score > 100 end)
        end

      assert check.(%{score: 150})
      refute check.(%{score: 50})
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

    test "on with Traversal (evaluated)" do
      check =
        pred do
          check(
            Traversal.combine([Lens.key(:score1), Lens.key(:score2)]),
            fn score -> score > 100 end
          )
        end

      # At least one score is > 100
      assert check.(%{score1: 150, score2: 50})
      assert check.(%{score1: 50, score2: 150})
      assert check.(%{score1: 150, score2: 150})

      # No scores > 100
      refute check.(%{score1: 50, score2: 50})
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

    test "0-arity helper returning Traversal" do
      check =
        pred do
          check(OpticHelpers.scores_traversal(), fn score -> score > 100 end)
        end

      assert check.(%{score1: 150, score2: 50})
      refute check.(%{score1: 50, score2: 50})
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
    # Only tuple syntax with options explicitly requires the behaviour.
    test "non-behaviour module alias is treated as bare predicate" do
      # This test exercises the parser path where a module alias without pred/1
      # is treated as a regular predicate (line 107 in parser.ex).

      defmodule NonBehaviourCallable do
        # Module without pred/1 but callable as a 1-arity function
        def __call__(user), do: user.age >= 18
      end

      # Use Code.eval_quoted to test the compilation phase properly
      # NonBehaviourCallable doesn't have pred/1, so it will hit the else clause
      # at line 107 and be treated as a bare predicate
      # At runtime, trying to call a module as a function will raise BadFunctionError
      assert_raise BadFunctionError, ~r/expected a function, got/, fn ->
        {_check, _binding} =
          Code.eval_quoted(
            quote do
              use Funx.Predicate

              check =
                pred do
                  NonBehaviourCallable
                end

              check.(%{age: 20})
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

  describe "error cases" do
    test "raises on empty any block" do
      assert_raise CompileError, ~r/Empty `any` block detected/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              any do
              end
            end
          end
        )
      end
    end

    test "raises on empty all block" do
      assert_raise CompileError, ~r/Empty `all` block detected/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Predicate

            pred do
              all do
              end
            end
          end
        )
      end
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

    test "warns on bare module reference without pred/1" do
      import ExUnit.CaptureIO

      warning =
        capture_io(:stderr, fn ->
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
        end)

      assert warning =~ "Bare module reference"
      assert warning =~ "NotABehaviour"
      assert warning =~ "does not implement Predicate.Dsl.Behaviour"
      assert warning =~ "BadFunctionError at runtime"
      assert warning =~ "Implement the Predicate.Dsl.Behaviour"
    end
  end
end
