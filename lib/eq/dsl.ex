defmodule Funx.Eq.Dsl do
  @moduledoc """
  Declarative DSL for building equality comparators over complex data structures.

  The DSL compiles at compile time into efficient `Eq` compositions using `contramap`,
  `concat_all`, and `concat_any`. This eliminates the need to manually compose equality
  functions while providing a clear, readable syntax for expressing multi-field equality checks.

  ## Basic Usage

      use Funx.Eq.Dsl

      eq do
        on :name
        on :age
      end

  ## Directives

    - `on` - Field/projection must be equal
    - `diff_on` - Field/projection must be different
    - `any` - At least one nested check must pass (OR logic)
    - `all` - All nested checks must pass (AND logic, implicit at top level)

  ## Projection Types

  The DSL supports the same projection forms as Ord DSL:

    - Atom - Field access via `Prism.key(atom)`
    - Atom with or_else - Optional field via `{Prism.key(atom), or_else}`
    - Function - Direct projection `fn x -> ... end` or `&fun/1`
    - Lens - Explicit lens for nested access (raises on missing)
    - Prism - Explicit prism for optional fields
    - Prism with or_else - `{Prism.t(), or_else}` for optional with fallback
    - Behaviour - Custom equality via `c:Funx.Eq.Dsl.Behaviour.eq/1`

  ## Equivalence Relations and diff_on

  **Core Eq** (using only `on`, `all`, `any`) forms an equivalence relation with three properties:

    - **Reflexive**: `eq?(a, a)` is always true
    - **Symmetric**: If `eq?(a, b)` then `eq?(b, a)`
    - **Transitive**: If `eq?(a, b)` and `eq?(b, c)` then `eq?(a, c)`

  These properties guarantee that Core Eq partitions values into equivalence classes, making it
  safe for use with Enum.uniq/2, MapSet, and grouping operations.

  **Extended Eq** (using `diff_on`) expresses boolean equality predicates and does not guarantee transitivity.

  Example of transitivity violation with `diff_on`:

      defmodule Person, do: defstruct [:name, :id]

      eq_diff_id = eq do
        on :name
        diff_on :id
      end

      a = %Person{name: "Alice", id: 1}
      b = %Person{name: "Alice", id: 2}
      c = %Person{name: "Alice", id: 1}

      eq?(a, b)  # true  (same name, different ids)
      eq?(b, c)  # true  (same name, different ids)
      eq?(a, c)  # false (same name, SAME id - violates diff_on)

  Even though `a == b` and `b == c`, we have `a != c`, violating transitivity.

  **Important**: If you need equivalence classes (grouping, uniq, set membership), do not use `diff_on`.

  ## Examples

  Basic multi-field equality:

      iex> use Funx.Eq.Dsl
      iex> defmodule Person, do: defstruct [:name, :age]
      iex> eq_person = eq do
      ...>   on :name
      ...>   on :age
      ...> end
      iex> Funx.Eq.Utils.eq?(%Person{name: "Alice", age: 30}, %Person{name: "Alice", age: 30}, eq_person)
      true

  Using diff_on to check difference:

      iex> use Funx.Eq.Dsl
      iex> defmodule Person, do: defstruct [:name, :email, :id]
      iex> eq_same_person = eq do
      ...>   on :name
      ...>   on :email
      ...>   diff_on :id
      ...> end
      iex> Funx.Eq.Utils.eq?(%Person{name: "Alice", email: "a@test.com", id: 1}, %Person{name: "Alice", email: "a@test.com", id: 2}, eq_same_person)
      true

  Nested any blocks (OR logic):

      iex> use Funx.Eq.Dsl
      iex> eq_contact = eq do
      ...>   any do
      ...>     on :email
      ...>     on :username
      ...>   end
      ...> end

  Mixed composition:

      iex> use Funx.Eq.Dsl
      iex> eq_mixed = eq do
      ...>   on :department
      ...>   any do
      ...>     on :email
      ...>     on :username
      ...>   end
      ...> end
  """

  alias Funx.Eq.Dsl.Executor
  alias Funx.Eq.Dsl.Parser

  defmacro __using__(_opts) do
    quote do
      import Funx.Eq.Dsl
    end
  end

  @doc """
  Creates an equality comparator from a block of projection specifications.

  Returns a `%Funx.Monoid.Eq.All{}` struct that can be used with `Funx.Eq.Utils`
  functions like `eq?/3`, `not_eq?/3`, or `to_predicate/2`.

  ## Examples

      eq do
        on :name
        on :age
      end

      eq do
        on :score, or_else: 0
        diff_on :id
      end

      eq do
        on :department
        any do
          on :email
          on :username
        end
      end
  """
  defmacro eq(do: block) do
    compile_eq(block, __CALLER__)
  end

  defp compile_eq(block, caller_env) do
    nodes = Parser.parse_operations(block, caller_env)
    Executor.execute_nodes(nodes)
  end
end
