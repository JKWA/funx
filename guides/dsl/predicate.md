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
* Built-in predicates - `Required`, `Integer`, `{Eq, value: :active}`, etc.
* 0-arity helper - Runtime predicate resolution

### Projection-Based Predicates (check directive)

The `check` directive composes a projection with a predicate. All projection syntax normalizes to one of:

* `Lens.t()` - Bare lens struct
* `Prism.t()` - Bare prism struct (Nothing fails the predicate)
* `(a -> b)` - Projection function

Syntax sugar for projections:

* `:atom` → `Prism.key(:atom)`
* `[:a, :b]` → `Prism.path([:a, :b])` (supports nested keys and structs)
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
* `negate check proj, pred` → `not compose_projection(projection, pred).(value)`
* `all do ... end` → `pred1.(value) and pred2.(value) and ...`
* `any do ... end` → `pred1.(value) or pred2.(value) or ...`
* `negate_all do ... end` → `not pred1.(value) or not pred2.(value) or ...` (De Morgan)
* `negate_any do ... end` → `not pred1.(value) and not pred2.(value) and ...` (De Morgan)

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

**With list path (nested fields):**

```elixir
check [:user, :profile, :age], fn age -> age >= 18 end
```

Equivalent to `check Prism.path([:user, :profile, :age]), fn age -> age >= 18 end`. The list path supports both atom keys and struct modules:

```elixir
defmodule User, do: defstruct [:name, :profile]
defmodule Profile, do: defstruct [:age, :verified]

check_adult = pred do
  check [User, :profile, Profile, :age], fn age -> age >= 18 end
end

user = %User{name: "Alice", profile: %Profile{age: 25, verified: true}}
check_adult.(user)  # true
```

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

## Built-in Predicates

Funx provides built-in predicate modules that implement `Funx.Predicate.Dsl.Behaviour`. These can be used directly in the DSL:

### Available Predicates

| Module | Required Option | Description |
|--------|----------------|-------------|
| `Eq` | `value:` | Checks equality using `Eq` comparator |
| `NotEq` | `value:` | Checks inequality using `Eq` comparator |
| `In` | `values:` | Checks membership in a list |
| `NotIn` | `values:` | Checks exclusion from a list |
| `LessThan` | `value:` | Checks `< value` using `Ord` comparator |
| `LessThanOrEqual` | `value:` | Checks `<= value` using `Ord` comparator |
| `GreaterThan` | `value:` | Checks `> value` using `Ord` comparator |
| `GreaterThanOrEqual` | `value:` | Checks `>= value` using `Ord` comparator |
| `IsTrue` | none | Checks strict `== true` |
| `IsFalse` | none | Checks strict `== false` |
| `MinLength` | `min:` | Checks string length `>= min` |
| `MaxLength` | `max:` | Checks string length `<= max` |
| `Pattern` | `regex:` | Checks string matches regex |
| `Integer` | none | Checks `is_integer/1` |
| `Positive` | none | Checks number `> 0` |
| `Negative` | none | Checks number `< 0` |
| `Required` | none | Checks not `nil` and not `""` |
| `Contains` | `value:` | Checks list contains element |

### Usage Syntax

Predicates without required options use bare module syntax:

```elixir
pred do
  check :count, Integer
  check :count, Positive
end
```

Predicates with options use tuple syntax:

```elixir
pred do
  check :status, {Eq, value: :active}
  check :age, {GreaterThanOrEqual, value: 18}
  check :name, {MinLength, min: 2}
end
```

### Default Truthy Check

When `check` is used with only a projection (no predicate), the parser inserts a default truthy check:

```elixir
pred do
  check :name  # equivalent to: check :name, fn v -> !!v end
end
```

The default predicate is `fn value -> !!value end`, following Elixir's truthiness rules where only `nil` and `false` are falsy.

### Required vs Truthy

The `Required` predicate differs from the default truthy check:

| Value | Default (truthy) | `Required` |
|-------|-----------------|------------|
| `"hello"` | true | true |
| `""` | true | **false** |
| `nil` | false | false |
| `false` | false | **true** |
| `0` | true | true |

Use `Required` when empty strings should fail but `false` should pass.

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

## Negation

The Predicate DSL supports negation at multiple levels using the `negate`, `negate_all`, and `negate_any` directives.

### Simple Negation

Use `negate` to invert any bare predicate:

```elixir
pred do
  negate is_banned
end
```

Compiles to: `not is_banned.(value)`

### Negating Projections

Use `negate check` to test that a projected value does NOT match a condition:

```elixir
pred do
  negate check :age, fn age -> age < 18 end
end
```

This is equivalent to checking that age >= 18, but handles missing fields safely (returns true if field is missing).

### Negating Blocks (De Morgan's Laws)

The `negate_all` and `negate_any` directives apply De Morgan's Laws to negate entire blocks:

**negate_all** - NOT (A AND B) = (NOT A) OR (NOT B)

```elixir
pred do
  negate_all do
    is_adult
    is_verified
  end
end
```

Compiles to: `not is_adult.(value) or not is_verified.(value)`

Returns `true` if at least one condition fails.

**negate_any** - NOT (A OR B) = (NOT A) AND (NOT B)

```elixir
pred do
  negate_any do
    is_vip
    is_admin
  end
end
```

Compiles to: `not is_vip.(value) and not is_admin.(value)`

Returns `true` only if all conditions fail (regular user, not special).

### Parser Transformation

The parser applies De Morgan's Laws at compile time:

* `negate_all do ... end` → `Block{strategy: :any, children: [negated...]}`
* `negate_any do ... end` → `Block{strategy: :all, children: [negated...]}`

This means negated blocks transform into their logical equivalent without requiring runtime negation of the entire block result.

### Execution Model (Updated)

Each directive compiles to:

* Bare predicate → `predicate.(value)`
* `check projection, pred` → `compose_projection(projection, pred).(value)`
* `negate predicate` → `not predicate.(value)`
* `negate check proj, pred` → `not compose_projection(projection, pred).(value)`
* `all do ... end` → `pred1.(value) and pred2.(value) and ...`
* `any do ... end` → `pred1.(value) or pred2.(value) or ...`
* `negate_all do ... end` → `not pred1.(value) or not pred2.(value) or ...`
* `negate_any do ... end` → `not pred1.(value) and not pred2.(value) and ...`

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
