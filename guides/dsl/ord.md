# Ord

The Ord DSL is a builder DSL that constructs ordering comparators for later use. See the [DSL Overview](overview.md) for the distinction between builder and pipeline DSLs.

## Structure

An `ord` block compiles entirely at compile time to quoted AST that builds an `%Funx.Monoid.Ord{}` struct. Unlike pipeline DSLs (Maybe, Either), there is no runtime executor—the DSL produces static composition of `contramap`, `reverse`, and `concat` calls that execute directly.

## Internal Representation

The Ord DSL uses a single structure type represented by `Step`:

* `Step` - Contains direction (`:asc` or `:desc`), projection AST, ord module, and metadata

Each Step describes a single ordering projection. The compiler pattern-matches on these structs to generate the final quoted AST.

```text
Compilation
    ├── Step (asc :name)
    ├── Step (desc :age)
    └── Step (asc :score, or_else: 0)
```

## Parser

The parser converts the DSL block into a list of structures. It normalizes all projection syntax into one of four canonical types that `contramap/2` accepts:

* `Lens.t()` - Bare lens struct
* `Prism.t()` - Bare prism struct (uses `Maybe.lift_ord`)
* `{Prism.t(), or_else}` - Prism with or_else value
* `(a -> b)` - Projection function

Plus special types for modules and runtime values:

* Module with `lt?/2` - Converted via `to_ord_map`
* Behaviour module - Calls `ord/1` at runtime
* 0-arity helper - Runtime type detection
* **Ord variable** - Runtime validation of ord map

All syntax sugar resolves to these types:

* `:atom` → `Prism.key(:atom)`
* `[:a, :b]` → `Prism.path([:a, :b])` (supports nested keys and structs)
* `:atom, or_else: x` → `{Prism.key(:atom), x}`
* `[:a, :b], or_else: x` → `{Prism.path([:a, :b]), x}`
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `{Prism, x}` → `{Prism, x}` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)
* `Behaviour` → `fn v -> Behaviour.project(v, []) end`
* `StructModule` → `fn v -> match?(%StructModule{}, v) end` (type filtering)
* `ord_variable` → runtime validation, use directly if valid ord map

The parser validates projections and raises compile-time errors for unsupported syntax, producing the final list of structures that the executor will compile.

## Transformers

The Ord DSL does not currently support transformers. All compilation is handled by the parser and executor without intermediate rewriting stages.

## Execution

The executor runs at compile time and generates quoted AST. It follows a single, non-branching path:

1. Take normalized structures from the parser
2. Wrap each in `Ord.contramap(projection, ord)`
3. Optionally wrap in `Ord.reverse(...)` for `:desc` direction
4. Combine all with `Ord.concat([...])` (or return single ord for one step)

### Execution Model

Each operation compiles based on its type:

**Regular projections:**
* `:asc` → `contramap(projection, ord)`
* `:desc` → `reverse(contramap(projection, ord))`

**Ord variables:**
* `:asc` → runtime validation, then use ord directly
* `:desc` → runtime validation, then `reverse(ord)`

Multiple operations are combined with `concat([...])` (monoid composition).

### No Implicit Tiebreaker

The DSL does NOT add an implicit tiebreaker. If two values are equal on all specified fields, they compare as `:eq`.

This means:

* You have explicit control over what matters for ordering
* DSL results can be composed without hidden tiebreakers in the middle
* DSL results can be used with `ord_for` macro without recursion issues

To add a tiebreaker, explicitly include `Funx.Ord.Protocol` as the last projection:

```elixir
ord do
  asc :name
  asc Funx.Ord.Protocol  # Falls back to struct's Ord implementation
end
```

### Compilation Example

```elixir
ord do
  asc :name
  desc :age
end
```

Compiles to:

```elixir
Ord.concat([
  Ord.contramap(Prism.key(:name), Funx.Ord.Protocol),
  Ord.reverse(Ord.contramap(Prism.key(:age), Funx.Ord.Protocol))
])
```

### List Paths (Nested Field Access)

List paths provide convenient syntax for accessing nested fields without manually composing optics:

```elixir
# Instead of:
ord do
  asc Prism.path([:user, :profile, :age])
end

# You can write:
ord do
  asc [:user, :profile, :age]
end
```

List paths support both atom keys and struct modules:

```elixir
defmodule Company, do: defstruct [:name, :address]
defmodule Address, do: defstruct [:city, :state]

# Sort companies by nested city
ord_by_city = ord do
  asc [Company, :address, Address, :city]
end

companies = [
  %Company{name: "ACME", address: %Address{city: "Seattle", state: "WA"}},
  %Company{name: "Corp", address: %Address{city: "Austin", state: "TX"}},
  %Company{name: "Inc", address: %Address{city: "Boston", state: "MA"}}
]

Enum.sort(companies, &Ord.lt?(&1, &2, ord_by_city))
# => [Austin, Boston, Seattle]
```

List paths work with `or_else` for handling missing values:

```elixir
ord do
  asc [:user, :profile, :score], or_else: 0
end
```

List paths work with `desc` for descending order:

```elixir
ord do
  desc [:user, :profile, :created_at]
end
```

## Ord Variables

Ord variables allow you to compose and reuse existing ord maps within the DSL. A variable holding an ord map can be used directly as a projection:

```elixir
base_ord = ord do
  asc :name
  desc :age
end

combined_ord = ord do
  asc :priority
  asc base_ord  # Use the ord variable
end

reversed_ord = ord do
  desc base_ord  # Reverse the ord variable
end
```

### How It Works

When the parser encounters a variable reference (not a module alias or literal), it marks it as `:ord_variable` type. The executor generates runtime validation code:

```elixir
# asc base_ord compiles to:
case base_ord do
  %{lt?: lt_fun, le?: le_fun, gt?: gt_fun, ge?: ge_fun}
  when is_function(lt_fun, 2) and is_function(le_fun, 2) and
       is_function(gt_fun, 2) and is_function(ge_fun, 2) ->
    base_ord  # Valid ord map, use it directly

  _ ->
    raise RuntimeError, "Expected an Ord map, got: #{inspect(base_ord)}"
end
```

This validation happens when the containing ord is created (not when it's used for comparison).

### What Works as an Ord Variable

Any value that is a valid ord map:

* `ord do ... end` - Ord maps from the DSL
* `Ord.contramap(...)` - Contramap projections
* `Ord.reverse(...)` - Reversed orderings
* `Ord.concat([...])` - Combined orderings
* `Ord.to_ord_map(module)` - Module-based orderings

### Composition Semantics

When you use an ord variable with `asc` or `desc`:

* `asc ord_var` - Uses the ord variable as-is
* `desc ord_var` - Reverses the ord variable

Ord variables preserve their complete ordering semantics when composed.

### Common Patterns

**Reversing complex orderings:**

```elixir
payment_ord = ord do
  asc Prism.key(:credit_card_payment)
  asc Prism.key(:credit_card_refund)
  asc Prism.key(:check_payment)
end

payment_desc = ord do
  desc payment_ord
end
```

**Building on base orderings:**

```elixir
name_age_ord = ord do
  asc :name
  desc :age
end

full_ord = ord do
  asc :priority
  asc name_age_ord
  asc :created_at
end
```

**Composing multiple ord variables:**

```elixir
primary_ord = ord do asc :group end
secondary_ord = ord do desc :score end
tertiary_ord = ord do asc :name end

complete_ord = ord do
  asc primary_ord
  asc secondary_ord
  asc tertiary_ord
end
```

## Behaviours

Modules participating in the Ord DSL implement `Funx.Ord.Dsl.Behaviour`. The parser converts behaviour module references into projection functions that call `project/2` on these modules. The behaviour's return value must be a comparable type (any type implementing the `Funx.Ord` protocol).

The `project/2` callback receives:

* `value` - The input value being projected
* `opts` - Keyword list of options passed in the DSL (e.g., `asc MyBehaviour, weight: 2.0`)

Example:

```elixir
defmodule WeightedScore do
  @behaviour Funx.Ord.Dsl.Behaviour

  @impl true
  def project(item, opts) do
    weight = Keyword.get(opts, :weight, 1.0)
    (item.score || 0) * weight
  end
end

ord do
  desc WeightedScore, weight: 2.0
end
```

The parser compiles this to `fn v -> WeightedScore.project(v, [weight: 2.0]) end`.
