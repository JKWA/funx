# Ord

## Structure

An `ord` block compiles entirely at compile time to quoted AST that builds an `%Funx.Monoid.Ord{}` struct. Unlike the Maybe and Either DSLs, there is no runtime executor—the DSL produces static composition of `contramap`, `reverse`, and `concat` calls that execute directly.

## Steps

The Ord DSL uses a single step type represented by `Step`:

* `Step` - Contains direction (`:asc` or `:desc`), projection AST, ord module, and metadata

Each step describes a single ordering projection. The compiler pattern-matches on these structs to generate the final quoted AST.

```text
Compilation
    ├── Step (asc :name)
    ├── Step (desc :age)
    ├── Step (asc :score, or_else: 0)
    └── Step (identity tiebreaker - implicit)
```

## Parser

The parser converts the DSL block into a step list. It normalizes all projection syntax into one of four canonical types that `contramap/2` accepts:

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
* `:atom, or_else: x` → `{Prism.key(:atom), x}`
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `{Prism, x}` → `{Prism, x}` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)
* `Behaviour` → `fn v -> Behaviour.project(v, []) end`
* `StructModule` → `fn v -> match?(%StructModule{}, v) end` (type filtering)
* `ord_variable` → runtime validation, use directly if valid ord map

The parser validates projections and raises compile-time errors for unsupported syntax, producing the final step list that the executor will compile.

## Transformers

The Ord DSL does not currently support transformers. All compilation is handled by the parser and executor without intermediate rewriting stages.

## Execution

The executor runs at compile time and generates quoted AST. It follows a single, non-branching path:

1. Take normalized steps from the parser
2. Wrap each in `Utils.contramap(projection, ord)`
3. Optionally wrap in `Utils.reverse(...)` for `:desc` direction
4. Combine all with `Utils.concat([...])`
5. Automatically append an identity tiebreaker step

### Execution Model

Each step compiles based on its type:

**Regular projections:**
* `:asc` → `contramap(projection, ord)`
* `:desc` → `reverse(contramap(projection, ord))`

**Ord variables:**
* `:asc` → runtime validation, then use ord directly
* `:desc` → runtime validation, then `reverse(ord)`

Multiple steps are combined with `concat([...])` (monoid composition).

### Implicit Identity Tiebreaker

A final identity projection (`fn x -> x end`) is automatically appended to ensure deterministic total ordering. This uses the value's `Ord` protocol implementation.

This means:

* Custom orderings are refinements of the domain's natural ordering
* No arbitrary tiebreaking via Elixir term ordering or insertion order
* Sorts are always deterministic and reproducible across runs

For example, if `Product` has `ord_for(Product, :amount)` defining its natural ordering, then `ord do asc :name end` will sort by name first, then by amount for ties.

### Compilation Example

```elixir
ord do
  asc :name
  desc :age
end
```

Compiles to:

```elixir
Utils.concat([
  Utils.contramap(Prism.key(:name), Funx.Ord),
  Utils.reverse(Utils.contramap(Prism.key(:age), Funx.Ord)),
  Utils.contramap(fn x -> x end, Funx.Ord)  # implicit identity
])
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
* `Utils.contramap(...)` - Contramap projections
* `Utils.reverse(...)` - Reversed orderings
* `Utils.concat([...])` - Combined orderings
* `Utils.to_ord_map(module)` - Module-based orderings

### Composition Semantics

When you use an ord variable with `asc` or `desc`:

* `asc ord_var` - Uses the ord variable as-is
* `desc ord_var` - Reverses the ord variable

Ord variables include their complete ordering semantics, including any implicit identity tiebreaker from their creation.

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
