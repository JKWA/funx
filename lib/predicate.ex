defmodule Funx.Predicate do
  @moduledoc """
  Provides utility functions for working with predicates—functions that return `true` or `false`.

  This module enables combining predicates in a declarative way using logical operations.

  ## Combinator Hierarchy

  The predicate algebra is built on three primitives:

  - `p_all/1`: Combines predicates with AND logic (structural primitive)
  - `p_any/1`: Combines predicates with OR logic (structural primitive)
  - `p_not/1`: Negates a predicate

  Binary convenience functions are thin wrappers over the primitives:

  - `p_and/2`: Binary AND, equivalent to `p_all([pred1, pred2])`
  - `p_or/2`: Binary OR, equivalent to `p_any([pred1, pred2])`
  - `p_none/1`: Negated OR, equivalent to `p_not(p_any(predicates))`

  The Predicate DSL compiles exclusively to `p_all`, `p_any`, and `p_not`, treating them
  as the canonical forms.

  ## Empty List Semantics

  The algebra allows empty lists and returns logical identity values:

  - `p_all([])` returns a predicate that always returns `true` (AND identity)
  - `p_any([])` returns a predicate that always returns `false` (OR identity)
  - `p_none([])` returns a predicate that always returns `true` (negated OR identity)

  **Note**: The Predicate DSL enforces non-empty `any` and `all` blocks at compile time,
  while the algebra combinators intentionally permit empty lists for composability.
  This distinction is deliberate: the algebra supports identity elements, the DSL enforces intent.

  ## Examples

  ### Combining predicates with `p_and/2`:

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Funx.Predicate.p_and(is_adult, has_ticket)
      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false

  ### Using `p_or/2` for alternative conditions:

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Funx.Predicate.p_or(is_vip, is_sponsor)
      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false

  ### Negating predicates with `p_not/1`:

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Funx.Predicate.p_not(is_minor)
      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false

  ### Using `p_all/1` and `p_any/1` for predicate lists:

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> conditions = [is_adult, has_ticket]
      iex> must_meet_all = Funx.Predicate.p_all(conditions)
      iex> must_meet_any = Funx.Predicate.p_any(conditions)
      iex> must_meet_all.(%{age: 20, tickets: 1})
      true
      iex> must_meet_all.(%{age: 20, tickets: 0})
      false
      iex> must_meet_any.(%{age: 20, tickets: 0})
      true
      iex> must_meet_any.(%{age: 16, tickets: 0})
      false

  ### Using `p_none/1` to reject multiple conditions:

      iex> is_adult = fn person -> person.age >= 18 end
      iex> is_vip = fn person -> person.vip end
      iex> cannot_enter = Funx.Predicate.p_none([is_adult, is_vip])
      iex> cannot_enter.(%{age: 20, vip: true})
      false
      iex> cannot_enter.(%{age: 16, vip: false})
      true
  """
  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]
  alias Funx.Monoid.Predicate.{All, Any}
  alias Funx.Optics.Traversal
  alias Funx.Predicate.Dsl.{Executor, Parser}

  @type t() :: (term() -> boolean())

  # ============================================================================
  # DSL Macros
  # ============================================================================

  defmacro __using__(_opts) do
    quote do
      import Funx.Predicate, only: [pred: 1]
    end
  end

  @doc """
  Creates a predicate from a block of predicate compositions.

  Returns a function `(any() -> boolean())` that can be used with `Enum.filter`,
  `Enum.find`, and other functions that accept predicates.

  ## Directives

    - Bare predicate - Include predicate in composition
    - `negate` - Negate the predicate
    - `check` - Compose projection with predicate (check projected value)
    - `any` - At least one nested predicate must pass (OR logic)
    - `all` - All nested predicates must pass (AND logic, implicit at top level)

  ## Predicate Forms

  The DSL accepts predicates in multiple forms:

  ### Variables (no parentheses needed)
  When a predicate is bound to a variable, reference it directly:

      is_adult = fn user -> user.age >= 18 end

      pred do
        is_adult  # Variable reference - no () needed
      end

  ### Helper Functions (parentheses required)
  When using 0-arity functions that return predicates, call them with `()`:

      defmodule Helpers do
        def adult?, do: fn user -> user.age >= 18 end
      end

      pred do
        Helpers.adult?()  # Must call with () to get the predicate
      end

  **Why `()` is required**: The DSL cannot distinguish at compile time between
  a function reference and a function call. Using `()` makes the intent explicit
  and ensures the predicate function is retrieved.

  ### Anonymous Functions (inline)
  Define predicates inline using `fn`:

      pred do
        fn user -> user.age >= 18 end
      end

  ### Captured Functions
  Use the capture operator `&` for named functions:

      pred do
        &adult?/1
      end

  ### Behaviour Modules
  For reusable validation logic, implement `Funx.Predicate.Dsl.Behaviour`:

      defmodule IsActive do
        @behaviour Funx.Predicate.Dsl.Behaviour

        def pred(_opts), do: fn user -> user.active end
      end

      pred do
        IsActive              # Bare module reference
        {HasMinimumAge, minimum: 21}  # With options
      end

  ## Examples

      use Funx.Predicate

      # Simple composition (implicit AND)
      pred do
        is_adult
        has_ticket
      end

      # With any block (OR logic)
      pred do
        is_admin

        any do
          is_vip
          is_sponsor
        end
      end

      # With negation
      pred do
        is_verified
        negate is_banned
      end

      # With projection (check directive)
      pred do
        is_adult
        check :email, fn email -> String.contains?(email, "@") end
      end

      # With negated projection
      pred do
        is_adult
        negate check :banned, fn b -> b == true end
      end

      # Complex nesting
      pred do
        any do
          all do
            is_admin
            is_verified
          end

          all do
            is_moderator
            has_permission
          end
        end

        negate is_suspended
      end
  """
  defmacro pred(do: block) do
    compile_predicate(block, __CALLER__)
  end

  defp compile_predicate(block, caller_env) do
    nodes = Parser.parse_operations(block, caller_env)
    Executor.execute_nodes(nodes)
  end

  # ============================================================================
  # Predicate Combinators
  # ============================================================================

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical AND.
  Returns a predicate that evaluates to `true` only if both `pred1` and `pred2` return `true`.

  ## Examples

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Funx.Predicate.p_and(is_adult, has_ticket)
      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false
  """
  @spec p_and(t(), t()) :: t()
  def p_and(pred1, pred2) when is_function(pred1) and is_function(pred2) do
    m_append(%All{}, pred1, pred2)
  end

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical OR.
  Returns a predicate that evaluates to `true` if either `pred1` or `pred2` return `true`.

  ## Examples

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Funx.Predicate.p_or(is_vip, is_sponsor)
      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false
  """
  @spec p_or(t(), t()) :: t()
  def p_or(pred1, pred2) when is_function(pred1) and is_function(pred2) do
    m_append(%Any{}, pred1, pred2)
  end

  @doc """
  Negates a predicate (`pred`).
  Returns a predicate that evaluates to `true` when `pred` returns `false`, and vice versa.

  ## Examples

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Funx.Predicate.p_not(is_minor)
      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false
  """
  @spec p_not(t()) :: t()
  def p_not(pred) when is_function(pred) do
    fn value -> not pred.(value) end
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical AND.
  Returns `true` only if all predicates return `true`. An empty list returns `true`.

  ## Examples

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Funx.Predicate.p_all([is_adult, has_ticket])
      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false
  """
  @spec p_all([t()]) :: t()
  def p_all(p_list) when is_list(p_list) do
    m_concat(%All{}, p_list)
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical OR.
  Returns `true` if at least one predicate returns `true`. An empty list returns `false`.

  ## Examples

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Funx.Predicate.p_any([is_vip, is_sponsor])
      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false
  """
  @spec p_any([t()]) :: t()
  def p_any(p_list) when is_list(p_list) do
    m_concat(%Any{}, p_list)
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical NOR (negated OR).
  Returns `true` only if **none** of the predicates return `true`. An empty list returns `true`.

  ## Examples

      iex> is_adult = fn person -> person.age >= 18 end
      iex> is_vip = fn person -> person.vip end
      iex> cannot_enter = Funx.Predicate.p_none([is_adult, is_vip])
      iex> cannot_enter.(%{age: 20, vip: true})
      false
      iex> cannot_enter.(%{age: 16, vip: false})
      true
  """
  @spec p_none([t()]) :: t()
  def p_none(p_list) when is_list(p_list) do
    p_not(p_any(p_list))
  end

  # ============================================================================
  # Projection Composition
  # ============================================================================

  @doc """
  Composes a projection (optic or function) with a predicate.

  This allows checking predicates on projected values (focused parts of data).

  ## Projection Types and Semantics

  ### Lens (Total Projection)
  - **Semantics**: Always focuses on a single value
  - **Success**: Applies predicate to the focused value
  - **Failure**: Raises if field is missing (total projection contract)
  - **Note**: The raising behavior is enforced by the Lens implementation (`lens.view/1`),
    not by this composition function. This function delegates to the Lens contract.

  ### Prism (Partial Projection)
  - **Semantics**: May focus on a value (returns Maybe monad)
  - **Success**: When focus succeeds (Just), applies predicate to unwrapped value
  - **Failure**: When focus fails (Nothing), returns `false` without applying predicate
  - **Contract**: Missing or nil values return `false`, not an error

  ### Traversal (Multi-Focus Projection)
  - **Semantics**: Focuses on zero or more values (returns list of foci)
  - **Success**: Returns `true` if **at least one** focused value passes the predicate (existential)
  - **Failure**: Returns `false` if **all** focused values fail or if no foci exist
  - **Contract**: Uses existential quantification (∃), not universal (∀)

  ### Function (Custom Projection)
  - **Semantics**: Projects value using the provided function
  - **Success**: Applies predicate to the function result
  - **Failure**: No built-in failure mode; function must handle edge cases

  ## Projection Failure Behavior

  When a projection fails to focus on a value:
  - **Prism**: Returns `false` (graceful degradation)
  - **Traversal** (empty foci): Returns `false`
  - **Lens**: Raises error (total projection contract violation)
  - **Function**: Depends on function implementation

  ## Examples

      iex> alias Funx.Optics.Prism
      iex> is_adult = fn age -> age >= 18 end
      iex> check = Funx.Predicate.compose_projection(Prism.key(:age), is_adult)
      iex> check.(%{age: 20})
      true
      iex> check.(%{age: 16})
      false
      iex> check.(%{})  # Missing key returns false
      false

      iex> alias Funx.Optics.Lens
      iex> is_long = fn s -> String.length(s) > 5 end
      iex> check = Funx.Predicate.compose_projection(Lens.key(:name), is_long)
      iex> check.(%{name: "Alexander"})
      true
      iex> check.(%{name: "Joe"})
      false

      iex> alias Funx.Optics.Traversal
      iex> # Existential: true if ANY score > 90
      iex> high_score = fn score -> score > 90 end
      iex> check = Funx.Predicate.compose_projection(
      ...>   Traversal.combine([Lens.key(:score1), Lens.key(:score2)]),
      ...>   high_score
      ...> )
      iex> check.(%{score1: 95, score2: 80})  # At least one passes
      true
      iex> check.(%{score1: 80, score2: 85})  # None pass
      false
  """
  @spec compose_projection(term(), t()) :: t()
  def compose_projection(projection, predicate) when is_function(predicate) do
    cond do
      lens?(projection) -> compose_with_lens(projection, predicate)
      prism?(projection) -> compose_with_prism(projection, predicate)
      traversal?(projection) -> compose_with_traversal(projection, predicate)
      true -> compose_with_function(projection, predicate)
    end
  end

  # Lens - has :view and :update keys
  defp lens?(projection) do
    is_map(projection) and Map.has_key?(projection, :view) and Map.has_key?(projection, :update)
  end

  defp compose_with_lens(lens, predicate) do
    fn value -> predicate.(lens.view.(value)) end
  end

  # Prism - has :preview and :review keys, returns Maybe monad
  defp prism?(projection) do
    is_map(projection) and Map.has_key?(projection, :preview) and
      Map.has_key?(projection, :review)
  end

  defp compose_with_prism(prism, predicate) do
    alias Funx.Monad.Maybe

    fn value ->
      case prism.preview.(value) do
        %Maybe.Just{value: focused_value} -> predicate.(focused_value)
        %Maybe.Nothing{} -> false
      end
    end
  end

  # Traversal - has :foci key
  defp traversal?(projection) do
    is_map(projection) and Map.has_key?(projection, :foci)
  end

  defp compose_with_traversal(traversal, predicate) do
    fn value ->
      focused_values = Traversal.to_list(value, traversal)
      Enum.any?(focused_values, predicate)
    end
  end

  # Function projection
  defp compose_with_function(fun, predicate) do
    unless is_function(fun, 1) do
      raise ArgumentError, """
      Expected a 1-arity function for projection, got: #{inspect(fun)}

      Valid projections are:
        - Lens (map with :view and :update keys)
        - Prism (map with :preview and :review keys)
        - Traversal (map with :foci key)
        - Function with arity 1: fn value -> ... end or &my_fun/1

      If you're using an optic, ensure it's properly constructed.
      If you're using a function, ensure it takes exactly one argument.
      """
    end

    fn value -> predicate.(fun.(value)) end
  end
end
