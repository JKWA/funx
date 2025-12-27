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

All syntax sugar resolves to these types:

* `:atom` → `Prism.key(:atom)`
* `:atom, or_else: x` → `{Prism.key(:atom), x}`
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `{Prism, x}` → `{Prism, x}` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)
* `Behaviour` → `fn v -> Behaviour.project(v, []) end`
* `StructModule` → `fn v -> match?(%StructModule{}, v) end` (type filtering)

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

Each step compiles to:

* `:asc` → `contramap(projection, ord)`
* `:desc` → `reverse(contramap(projection, ord))`

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
