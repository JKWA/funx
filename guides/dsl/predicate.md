# Predicate

The Predicate DSL is a builder DSL that constructs boolean predicates for later use. See the [DSL Overview](overview.md) for the distinction between builder and pipeline DSLs.

## Structure

A `pred` block compiles entirely at compile time to quoted AST that builds a predicate function. Unlike pipeline DSLs (Maybe, Either), there is no runtime executor—the DSL produces static composition of boolean logic that executes directly.

## Internal Representation

The Predicate DSL uses two structure types to represent the predicate composition:

* `Step` - Contains predicate AST, projection AST (optional), negate flag, type, and metadata
* `Block` - Contains strategy (`:all` or `:any`), children, and metadata

Each Step describes a single predicate check (bare predicate or projection with predicate). Each Block groups multiple checks with AND/OR logic. The compiler pattern-matches on these structs to generate the final quoted AST.

```text
Compilation
    ├── Block (all - implicit at top level)
    │   ├── Step (bare predicate)
    │   ├── Step (check :field, predicate)
    │   └── Block (any)
    │       ├── Step (predicate1)
    │       └── Step (predicate2)
```

## Parser

The parser converts the DSL block into a tree of Step and Block structures. It normalizes all syntax into canonical types:

### Bare Predicates

* `(a -> boolean)` - Function predicate
* Variable reference - Resolved at runtime
* Module implementing Behaviour - Calls `pred/1` at runtime
* `{Module, opts}` - Behaviour with options
* 0-arity helper - Runtime predicate resolution

### Projection-Based Predicates (check directive)

The `check` directive composes a projection with a predicate. All projection syntax normalizes to one of:

* `Lens.t()` - Bare lens struct
* `Prism.t()` - Bare prism struct (Nothing fails the predicate)
* `(a -> b)` - Projection function

Syntax sugar for projections:

* `:atom` → `Prism.key(:atom)`
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)
* `Traversal.t()` → Converted to projection function

The parser validates predicates and projections, raising compile-time errors for unsupported syntax.

## Transformers

The Predicate DSL does not currently support transformers. All compilation is handled by the parser and executor without intermediate rewriting stages.

## Execution

The executor runs at compile time and generates quoted AST. It recursively walks the structure tree:

1. Take normalized structures from the parser
2. For each Step:
   * If bare predicate → generate predicate call
   * If `check projection, pred` → compose projection with predicate
   * If `negate: true` → wrap in boolean negation
3. For each Block:
   * If `strategy: :all` → combine children with AND logic
   * If `strategy: :any` → combine children with OR logic
4. Top-level operations are implicitly combined with AND logic

### Execution Model

An empty `pred` block compiles to a predicate that always returns `true`.

Each directive compiles to:

* Bare predicate → `predicate.(value)`
* `check projection, pred` → `compose_projection(projection, pred).(value)`
* `negate predicate` → `not predicate.(value)`
* `all do ... end` → `pred1.(value) and pred2.(value) and ...`
* `any do ... end` → `pred1.(value) or pred2.(value) or ...`

### Projection Composition

The `check` directive composes projections with predicates:

**With Lens:**
```elixir
check Lens.key(:age), fn age -> age >= 18 end
```
Compiles to a function that gets the value, then tests it.

**With Prism:**
```elixir
check Prism.key(:email), fn email -> String.contains?(email, "@") end
```
Compiles to a function that returns `false` if the prism returns `Nothing`, otherwise tests the focused value.

**With atom (sugar for Prism.key):**
```elixir
check :name, fn name -> String.length(name) > 5 end
```
Equivalent to `check Prism.key(:name), fn name -> String.length(name) > 5 end`.

### Compilation Example

```elixir
pred do
  check :active, fn active -> active end
  any do
    check :role, fn role -> role == :admin end
    check :verified, fn verified -> verified end
  end
end
```

Compiles to a function equivalent to:

```elixir
fn value ->
  (case Prism.preview(value, Prism.key(:active)) do
    {:ok, active} -> active
    :error -> false
  end) and
  (case Prism.preview(value, Prism.key(:role)) do
    {:ok, role} -> role == :admin
    :error -> false
  end or
  case Prism.preview(value, Prism.key(:verified)) do
    {:ok, verified} -> verified
    :error -> false
  end)
end
```

## Behaviours

Modules participating in the Predicate DSL implement `Funx.Predicate.Dsl.Behaviour`. The parser detects behaviour modules and calls their `pred/1` callback, which must return a predicate function.

The `pred/1` callback receives:

* `opts` - Keyword list of options passed in the DSL (e.g., `{HasMinimumAge, minimum: 21}`)

Example:

```elixir
defmodule HasMinimumAge do
  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(opts) do
    minimum = Keyword.get(opts, :minimum, 18)
    fn user -> user.age >= minimum end
  end
end

pred do
  {HasMinimumAge, minimum: 21}
end
```

The parser compiles this to a call to `HasMinimumAge.pred([minimum: 21])` which returns the predicate function.

## Boolean Logic

The Predicate DSL supports two composition strategies:

### All (AND Logic)

Using bare predicates or explicit `all` blocks creates AND composition where all predicates must pass:

```elixir
pred do
  is_active
  is_verified
  is_adult
end
```

Equivalent to:

```elixir
pred do
  all do
    is_active
    is_verified
    is_adult
  end
end
```

### Any (OR Logic)

Using `any` blocks creates OR composition where at least one predicate must pass:

```elixir
pred do
  any do
    is_admin
    is_moderator
  end
end
```

### Nesting

Blocks can be nested arbitrarily deep for complex logic:

```elixir
pred do
  is_active
  any do
    is_admin
    all do
      is_verified
      is_adult
    end
  end
end
```

This reads as: "active AND (admin OR (verified AND adult))"

## Integration with Enum

Predicates built with the DSL work seamlessly with Elixir's Enum module:

```elixir
check_eligible = pred do
  check :age, fn age -> age >= 18 end
  check :verified, fn verified -> verified end
end

# Filter
Enum.filter(users, check_eligible)

# Find
Enum.find(users, check_eligible)

# Count
Enum.count(users, check_eligible)

# Any/All
Enum.any?(users, check_eligible)
Enum.all?(users, check_eligible)

# Partition
Enum.split_with(users, check_eligible)
```
