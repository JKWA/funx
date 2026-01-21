# `Funx.Eq` Usage Rules

## Core Concepts

**Protocol + Custom Eq Pattern**: Use both together for maximum flexibility

- **Protocol implementation** = domain's default equality (whatever makes business sense)
- **Custom Eq injection** = context-specific equality when needed
- **Key insight**: Protocol provides sensible defaults, custom Eq provides flexibility

**Contramap**: Contravariant functor - transforms inputs before comparison

- `contramap(& &1.id, Eq)` compares by ID field only
- Mathematical dual of `map` - transforms "backwards" through the data flow
- Key pattern: transform the input, not the comparison result

**Utils Pattern**: Inject custom Eq logic or default to protocol

- `Eq.eq?(a, b, custom_eq)` - uses custom_eq
- `Eq.eq?(a, b)` - uses protocol dispatch

**Monoid Composition**: Combine equality checks

- `append_all/any(eq1, eq2)` - combine two (FALSE/TRUE-biased)
- `concat_all/any([eq1, eq2, eq3])` - combine list (FALSE/TRUE-biased)

## Quick Patterns

```elixir
# STEP 1: Implement protocol for domain's default equality
defimpl Funx.Eq, for: User do
  def eq?(%User{id: id1}, %User{id: id2}), do: Funx.Eq.eq?(id1, id2)
  def not_eq?(a, b), do: not eq?(a, b)
end

# STEP 2: Use protocol directly for default equality
Eq.eq?(user1, user2)  # Uses protocol (by ID)
List.uniq(users)      # Uses protocol default

# STEP 3: Inject custom Eq for specific contexts
by_name = Eq.contramap(& &1.name)
Eq.eq?(user1, user2, by_name)  # Compare by name instead
List.uniq(users, by_name)            # Dedupe by name, not ID

# Combine fields
name_and_age = Eq.concat_all([
  Eq.contramap(& &1.name),
  Eq.contramap(& &1.age)
])

# Use with Funx.List
Funx.List.uniq(users, by_id)
```

## Key Rules

- **IMPLEMENT PROTOCOL** for domain's default equality (whatever makes business sense)
- **USE CUSTOM EQ** when you need different equality for specific operations
- **MUST implement both** `eq?/2` and `not_eq?/2` (no optional defaults)
- **Best practice**: `not_eq?(a, b) = not eq?(a, b)`
- Use `contramap/2` to transform inputs before comparison
- Use monoid functions for composition: `append_all/any`, `concat_all/any`
- Pattern: Protocol for defaults, Utils injection for flexibility

## When to Use

- **Protocol implementation**: When you need domain's default equality (whatever makes business sense, not structural equality)
- **Custom Eq injection**: When you need different equality for specific contexts
- Deduplication with `Funx.List.uniq/2` (protocol default or custom)
- Set operations (`union`, `intersection`, etc.)
- Context-specific filtering and comparison logic

## Anti-Patterns

```elixir
# ❌ Don't mix == and Eq.eq?
if user1 == user2 and Eq.eq?(user1.name, user2.name), do: ...

# ❌ Don't forget not_eq?/2
defimpl Funx.Eq, for: User do
  def eq?(%User{id: id1}, %User{id: id2}), do: id1 == id2
  # Missing not_eq?/2!
end

# ❌ Don't transform comparison result
contramap(fn result -> not result end)  # Wrong!
```

## Testing

```elixir
test "Eq laws hold" do
  # Reflexivity: a == a
  assert Eq.eq?(user, user)
  
  # Symmetry: a == b implies b == a  
  assert Eq.eq?(user1, user2) == Eq.eq?(user2, user1)
  
  # Complement: eq? and not_eq? are opposites
  assert Eq.eq?(user1, user2) == not Eq.not_eq?(user1, user2)
end

test "contramap preserves Eq laws" do
  by_id = Eq.contramap(& &1.id)
  user1 = %User{id: 1, name: "Alice"}
  user2 = %User{id: 1, name: "Bob"}  # Same ID, different name
  
  # Contramap projection maintains equality laws
  assert by_id.eq?.(user1, user2)  # Same ID
  assert by_id.eq?.(user1, user1)  # Reflexive
end

test "monoid composition laws" do
  eq1 = Eq.contramap(& &1.name)
  eq2 = Eq.contramap(& &1.age)
  
  # Monoid bias behavior
  all_eq = Eq.concat_all([eq1, eq2])  # FALSE-biased
  any_eq = Eq.concat_any([eq1, eq2])  # TRUE-biased
  
  person1 = %{name: "Alice", age: 25}
  person2 = %{name: "Alice", age: 30}  # Name matches, age differs
  
  assert any_eq.eq?.(person1, person2)  # TRUE-bias: stops at name match
  refute all_eq.eq?.(person1, person2) # FALSE-bias: fails on age difference
end
```

## Fallback Behavior

- **Any protocol**: Uses Elixir's `==` and `!=` for primitive types
- **Custom types**: Define explicit `Eq` implementation for domain logic
- **Time types**: Built-in instances use standard library comparison

## Eq DSL

The Eq DSL is a builder DSL that constructs equality comparators for later use. See the [DSL guides](../guides/dsl/overview.md) for the distinction between builder and pipeline DSLs.

The DSL provides a declarative syntax for building complex equality comparisons without explicit `contramap`, `concat_all`, and `concat_any` calls.

**Design Philosophy:**

- **Declarative equality** - Describe what fields to compare, not how to compare
- **Compile-time composition** - DSL expands to static `Eq` compositions at compile time
- **Boolean structure** - `on`, `diff_on`, `all`, `any` directives for flexible logic
- **Type-safe projections** - Leverages Lens and Prism for safe data access

**Key Benefits:**

- Clean, readable multi-field equality checks
- Automatic handling of nil values with Prism semantics
- Explicit Lens for required fields, atoms for optional fields
- Nested `any`/`all` blocks for OR/AND logic
- Zero runtime overhead - compiles to direct function calls
- No implicit tiebreaker (unlike Ord DSL)

### Basic Usage

```elixir
use Funx.Eq

eq do
  on :name
  on :age
end
```

### Practical Comparison: Before and After

**With Utils functions (manual composition):**

```elixir
Eq.concat_all([
  Eq.contramap(Prism.key(:name), Funx.Eq),
  Eq.contramap(Prism.key(:age), Funx.Eq)
])
```

**With Eq DSL (declarative):**

```elixir
eq do
  on :name
  on :age
end
```

The DSL version:

- ✅ More readable (clear equality intent)
- ✅ More concise (no manual contramap/concat)
- ✅ Type-safe (compile-time projection validation)
- ✅ Same performance (expands to identical code)

### Directives

- `on <projection>` - Field/projection must be equal
- `diff_on <projection>` - Field/projection must be different
- `any do ... end` - At least one nested check must pass (OR logic)
- `all do ... end` - All nested checks must pass (AND logic, implicit at top level)

### Supported Projections

- `on :atom` - Field access via `Prism.key/1` (Nothing == Nothing)
- `on [:a, :b]` - List path via `Prism.path/1` (nested keys and structs, Nothing == Nothing)
- `on :atom, or_else: value` - Prism with fallback (replaces Nothing with value)
- `on [:a, :b], or_else: value` - List path with fallback
- `on Lens.key(:field)` - Explicit Lens (total access, raises `KeyError` on missing keys)
- `on Lens.path([:a, :b])` - Nested Lens (raises on missing keys or nil intermediate values)
- `on Prism.key(:field)` - Explicit Prism (Nothing == Nothing)
- `on {Prism.key(:field), default}` - Prism tuple (replaces Nothing with default)
- `on &String.length/1` - Function projection
- `on fn x -> x.field end` - Anonymous function
- `on MyModule.my_projection()` - Helper function (0-arity)
- `on MyBehaviour` - Behaviour module returning Eq map
- `on MyBehaviour, opt: value` - Behaviour with options
- `on MyStruct` - Struct module (uses protocol)

Same projections work with `diff_on` to check inequality.

### DSL Examples

**Basic multi-field equality:**

```elixir
eq do
  on :name
  on :age
end
```

**Handling nil values with or_else:**

```elixir
eq do
  on :score, or_else: 0
  on :name
end
```

**Using diff_on to check difference:**

```elixir
# Same person (name + email), different record (id differs)
eq do
  on :name
  on :email
  diff_on :id
end
```

**OR logic with any blocks:**

```elixir
# Match if email OR username is the same
eq do
  any do
    on :email
    on :username
  end
end
```

**Mixed AND/OR logic:**

```elixir
# Same department AND (email OR username matches)
eq do
  on :department
  any do
    on :email
    on :username
  end
end
```

**Nested blocks:**

```elixir
eq do
  on :name
  any do
    on :email
    all do
      on :age
      on :username
    end
  end
end
```

**Custom behaviour:**

```elixir
defmodule FuzzyStringEq do
  @behaviour Funx.Eq.Dsl.Behaviour

  @impl true
  def eq(opts) do
    threshold = Keyword.get(opts, :threshold, 0.8)

    %{
      eq?: fn a, b -> string_similarity(a, b) >= threshold end,
      not_eq?: fn a, b -> string_similarity(a, b) < threshold end
    }
  end

  defp string_similarity(a, b), do: # ...
end

eq do
  on FuzzyStringEq, threshold: 0.9
end
```

### Projection Type Selection Guide

**Use atoms (`:field`) when:**

- Field might be missing or nil, and you want `Nothing == Nothing` semantics
- You want safe, forgiving data access (no exceptions)
- You don't need to enforce field existence

**Use Lens when:**

- Field must exist (domain invariant)
- You want fail-fast on missing keys (raises `KeyError`)
- You need nested field access with total guarantees

**Use Prism when:**

- You need to work with sum types (variants)
- You want explicit partial access with Maybe semantics (`Nothing == Nothing`)
- You're composing with other Prisms
- You need type-safe pattern matching on variants

**Use functions when:**

- You need custom transformation logic
- Projection doesn't map to a simple field
- You're computing derived values

**Use behaviours when:**

- Logic is complex and reusable (e.g., fuzzy matching)
- You need parameterized comparisons
- You want to share comparison logic across modules

### Lens vs Prism vs Atoms

**Critical difference in nil handling:**

```elixir
# Atom: Uses Prism (Nothing == Nothing)
eq do
  on :value
end
# nil == nil is true

# Explicit Lens: Extracts nil, uses Elixir ==
eq do
  on Lens.key(:value)
end
# nil == nil is true (but raises KeyError if key missing)

# Explicit Prism with or_else: Replace nil with default
eq do
  on :value, or_else: 0
end
# nil becomes 0 for comparison
```

**When to use each:**

- **Lens** - Lawful total optic. Unconditional extraction. Raises `KeyError` on missing keys, or when intermediate path values are nil.
- **Prism** - Lawful partial optic. Returns `Maybe` (`Nothing` for missing/nil, `Just(value)` for present). `Nothing == Nothing` is true.
- **Atoms** - Convenience syntax using `Prism.key/1`. Safe for optional fields.
- **Prism with or_else** - Replaces `Nothing` with a default value before comparison.

### Compile-Time Safety

**Valid or_else usage:**

```elixir
# ✅ Atoms accept or_else
eq do
  on :score, or_else: 0
end

# ✅ Explicit Prisms accept or_else
eq do
  on Prism.key(:score), or_else: 0
end

# ✅ Helper functions returning Prisms accept or_else
eq do
  on ProjectionHelpers.score_prism(), or_else: 0
end
```

**Invalid or_else usage (compile error):**

```elixir
# ❌ Lens cannot use or_else
eq do
  on Lens.key(:name), or_else: "Unknown"
end

# ❌ Functions cannot use or_else
eq do
  on &String.length/1, or_else: 0
end

# ❌ Behaviours cannot use or_else
eq do
  on MyBehaviour, or_else: 0
end

# ❌ Redundant or_else with tuple syntax
eq do
  on {Prism.key(:score), 0}, or_else: 10
end

# ❌ Traversal cannot use or_else
eq do
  on Traversal.combine([Lens.key(:name)]), or_else: "unknown"
end
```

### Equivalence Relations and diff_on

**Core Eq (using `on`, `all`, `any`)** forms an equivalence relation:

- **Reflexive**: `eq?(a, a)` is always true
- **Symmetric**: If `eq?(a, b)` then `eq?(b, a)`
- **Transitive**: If `eq?(a, b)` and `eq?(b, c)` then `eq?(a, c)`

Core Eq safely partitions values into equivalence classes, making it suitable for:

- `Funx.List.uniq/2` - Remove duplicates
- `MapSet` - Set membership
- `Enum.group_by/2` - Grouping operations

**Extended Eq (using `diff_on`)** does NOT guarantee transitivity:

```elixir
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
```

**Rule**: If you need equivalence classes (grouping, uniq, sets), do not use `diff_on`. Use it only for boolean predicates where transitivity is not required.

### Working with Lists

```elixir
people = [
  %Person{name: "Alice", age: 30, email: "alice@test.com"},
  %Person{name: "Alice", age: 30, email: "alice@test.com"},
  %Person{name: "Bob", age: 25, email: "bob@test.com"}
]

eq_person = eq do
  on :name
  on :age
  on :email
end

# With Funx.List
Funx.List.uniq(people, eq_person)  # [Alice, Bob]

# Note: Use Funx.List.uniq/2 for custom Eq support
# Enum.uniq_by/2 doesn't support custom Eq directly
```

### Helper Functions Pattern

Define reusable projections as 0-arity functions:

```elixir
defmodule ProjectionHelpers do
  alias Funx.Optics.{Lens, Prism}

  def name_lens, do: Lens.key(:name)
  def age_lens, do: Lens.key(:age)
  def score_prism, do: Prism.key(:score)
  def score_with_default, do: {Prism.key(:score), 0}
end

# Use in DSL
eq do
  on ProjectionHelpers.name_lens()
  on ProjectionHelpers.age_lens()
  on ProjectionHelpers.score_with_default()
end
```

### Nested Field Access (List Paths)

List paths provide convenient syntax for accessing nested fields:

```elixir
# Using list path syntax (recommended)
eq_by_city = eq do
  on [:company, :address, :city]
end

# Equivalent to explicit Prism.path
eq_by_city = eq do
  on Prism.path([:company, :address, :city])
end

# Or using Lens.path for total access
eq_by_city = eq do
  on Lens.path([:company, :address, :city])
end
```

**List paths with struct modules:**

```elixir
employees = [
  %Employee{
    name: "Alice",
    company: %Company{
      address: %Address{city: "Austin", state: "TX"}
    }
  }
]

# Struct-aware path
eq_by_city = eq do
  on [Employee, :company, Company, :address, Address, :city]
end

Eq.eq?(emp1, emp2, eq_by_city)
```

**List paths with or_else:**

```elixir
# Handle missing nested values
eq_with_default = eq do
  on [:user, :profile, :city], or_else: "Unknown"
end
```

**Multiple list paths:**

```elixir
eq_nested = eq do
  on [:user, :profile, :name]
  on [:user, :profile, :age]
end
```

### Empty Eq Block

An empty `eq` block creates an identity equality (all values are equal):

```elixir
eq_identity = eq do
end

Eq.eq?(anything, anything_else, eq_identity)  # Always true
```

**Warning**: This will cause `Funx.List.uniq/2` and `MapSet` to collapse all values into a single equivalence class.

### When to Use the DSL

**✅ Use the DSL when:**

- You need multi-field equality checks
- You want declarative, readable equality definitions
- You're combining different projection types
- You need OR logic (any blocks)
- You want nil-safe field access
- You want compile-time validation
- You prefer pipeline-friendly syntax

**❌ Use Utils functions when:**

- You only need single-field comparison (DSL may be overkill)
- You're building dynamic equality at runtime (DSL is compile-time only)
- You need fine-grained control over composition
- You prefer explicit function composition over macro expansion
- You're implementing reusable combinator libraries

### Common DSL Patterns

**User identity (same person, different record):**

```elixir
eq_same_user = eq do
  on :email
  on :username
  diff_on :id  # Must be different records
end
```

**Contact matching (email OR phone):**

```elixir
eq_contact = eq do
  on :name
  any do
    on :email
    on :phone
  end
end
```

**Product equivalence (ignore metadata):**

```elixir
eq_product = eq do
  on :sku
  on :name
  on :price
  # Ignoring: created_at, updated_at, id
end
```

**Fuzzy matching:**

```elixir
eq_fuzzy_name = eq do
  on FuzzyStringEq, threshold: 0.85
  on :birth_date
end
```

### Formatter Configuration

Funx exports formatter rules for clean DSL formatting. Add to `.formatter.exs`:

```elixir
[
  import_deps: [:funx],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

This formats DSL code cleanly without parentheses:

```elixir
# With formatter rules (clean)
eq do
  on :name
  on :age
end

# Without formatter rules (parentheses added)
eq() do
  on(:name)
  on(:age)
end
```

### Comparison with Manual Composition

The DSL is syntactic sugar over Utils functions:

```elixir
# DSL
eq do
  on :name
  on :age
  any do
    on :email
    on :username
  end
end

# Equivalent Utils composition
Eq.concat_all([
  Eq.contramap(Prism.key(:name), Funx.Eq),
  Eq.contramap(Prism.key(:age), Funx.Eq),
  Eq.concat_any([
    Eq.contramap(Prism.key(:email), Funx.Eq),
    Eq.contramap(Prism.key(:username), Funx.Eq)
  ])
])
```

Both compile to identical code - the DSL just makes it more readable.

### Testing DSL Equalities

```elixir
test "multi-field equality" do
  alice1 = %Person{name: "Alice", age: 30}
  alice2 = %Person{name: "Alice", age: 30}
  bob = %Person{name: "Bob", age: 30}

  eq_person = eq do
    on :name
    on :age
  end

  # Same name and age
  assert Eq.eq?(alice1, alice2, eq_person)

  # Different name
  refute Eq.eq?(alice1, bob, eq_person)
end

test "nil handling with or_else" do
  with_score = %Item{name: "A", score: 100}
  without_score = %Item{name: "B", score: nil}

  eq_item = eq do
    on :score, or_else: 0
  end

  # nil becomes 0, 0 != 100
  refute Eq.eq?(without_score, with_score, eq_item)
end

test "any block (OR logic)" do
  alice_email = %Person{email: "alice@test.com", username: "alice"}
  alice_username = %Person{email: "different@test.com", username: "alice"}
  bob = %Person{email: "bob@test.com", username: "bob"}

  eq_contact = eq do
    any do
      on :email
      on :username
    end
  end

  # Username matches (OR logic)
  assert Eq.eq?(alice_email, alice_username, eq_contact)

  # Neither matches
  refute Eq.eq?(alice_email, bob, eq_contact)
end

test "diff_on directive" do
  alice1 = %Person{name: "Alice", email: "a@test.com", id: 1}
  alice2 = %Person{name: "Alice", email: "a@test.com", id: 2}

  eq_same_person_diff_record = eq do
    on :name
    on :email
    diff_on :id
  end

  # Same person, different records
  assert Eq.eq?(alice1, alice2, eq_same_person_diff_record)

  # Same record (id matches - violates diff_on)
  refute Eq.eq?(alice1, alice1, eq_same_person_diff_record)
end
```

### Performance Characteristics

- **Compile-time expansion** - DSL compiles to static function calls
- **Zero runtime overhead** - No interpretation or dispatch
- **Efficient composition** - Uses monoid concatenation
- **Short-circuit evaluation** - `concat_all` stops on first false, `concat_any` stops on first true
- **Memory efficient** - No intermediate allocations

### Key Differences from Ord DSL

- **No direction field** - Equality is symmetric (no asc/desc)
- **No implicit tiebreaker** - Empty eq block is identity (all equal)
- **Tree structure** - Nested `all`/`any` blocks vs linear operations
- **diff_on directive** - Check inequality (breaks transitivity)
- **Different monoids** - `Eq.All` (AND) and `Eq.Any` (OR) vs `Ord` monoid

### DSL Summary

The Eq DSL provides declarative multi-field equality:

**Core Directives:**

- `on <projection>` - Field must be equal
- `diff_on <projection>` - Field must be different (breaks transitivity)
- `any do ... end` - OR logic (at least one must match)
- `all do ... end` - AND logic (all must match)

**Key Patterns:**

- Use atoms for optional fields (`Nothing == Nothing`)
- Use Lens for required fields (raises `KeyError` on missing keys)
- Use Prism explicitly for sum types with partial access (`Nothing == Nothing`)
- Use Prism with or_else for optional fields with specific defaults
- Use behaviours for complex, reusable equality logic (fuzzy matching, etc.)
- Nested `any`/`all` blocks for complex boolean logic
- No implicit tiebreaker (unlike Ord DSL)
- Avoid `diff_on` if you need equivalence classes (grouping, uniq, sets)

**Remember:** The Eq DSL compiles to Utils function calls at compile time - use whichever syntax is clearer for your use case.

## Summary

`Funx.Eq` provides **extensible, composable equality** for domain semantics beyond structural `==`:

- **Contramap** (contravariant functor): Transform inputs before comparison
- **Monoid composition**: Combine equality checks with FALSE/TRUE-biased operations
- **Utils injection**: `Eq.eq?(a, b, custom_eq)` pattern for flexible equality
- **Protocol + fallback**: Custom domain logic with `Any` fallback for primitives
- **Mathematical foundation**: Preserves equality laws through transformations and composition
- **Eq DSL**: Declarative syntax for complex multi-field equality with boolean structure

**Canon**: Use `contramap` for projections, monoid functions for composition, Utils injection for flexibility, DSL for declarative multi-field checks.
