# Eq

## Structure

An `eq` block compiles entirely at compile time to quoted AST that builds an `%Funx.Monoid.Eq.All{}` struct. Unlike the Maybe and Either DSLs, there is no runtime executor—the DSL produces static composition of `contramap`, `concat_all`, and `concat_any` calls that execute directly.

## Nodes

The Eq DSL uses two node types to represent the equality tree:

* `Step` - Contains projection AST, eq module, negate flag, type, and metadata
* `Block` - Contains strategy (`:all` or `:any`), children nodes, and metadata

Each Step describes a single equality check (on a field or projection). Each Block groups multiple checks with AND/OR logic. The compiler pattern-matches on these structs to generate the final quoted AST.

```text
Compilation
    ├── Block (all - implicit at top level)
    │   ├── Step (on :name)
    │   ├── Step (on :age)
    │   └── Block (any)
    │       ├── Step (on :email)
    │       └── Step (on :username)
```

## Parser

The parser converts the DSL block into a tree of Step and Block nodes. It normalizes all projection syntax into one of four canonical types that `contramap/2` accepts:

* `Lens.t()` - Bare lens struct
* `Prism.t()` - Bare prism struct (Nothing == Nothing)
* `{Prism.t(), or_else}` - Prism with or_else value
* `(a -> b)` - Projection function

All syntax sugar resolves to these types:

* `:atom` → `Prism.key(:atom)`
* `:atom, or_else: x` → `{Prism.key(:atom), x}`
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `{Prism, x}` → `{Prism, x}` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)
* `Behaviour` → Behaviour.eq([]) (returns Eq map)
* `StructModule` → `Utils.to_eq_map(StructModule)` (uses protocol)

Additionally, the parser tracks a `type` field for each Step to enable compile-time optimization:

* `:projection` - Optics or functions → wrap in contramap
* `:module_eq` - Module with `eq?/2` → convert via `to_eq_map`
* `:eq_map` - Behaviour returning Eq map → use directly
* `:dynamic` - Unknown (0-arity helper) → runtime detection

The parser validates projections and raises compile-time errors for unsupported syntax, producing the final node tree that the executor will compile.

## Transformers

The Eq DSL does not currently support transformers. All compilation is handled by the parser and executor without intermediate rewriting stages.

## Execution

The executor runs at compile time and generates quoted AST. It recursively walks the node tree:

1. Take normalized nodes from the parser
2. For each Step:
   * If `negate: false` → `Utils.contramap(projection, eq)`
   * If `negate: true` → `Utils.contramap(projection, negated_eq)`
3. For each Block:
   * If `strategy: :all` → `Utils.concat_all([children...])`
   * If `strategy: :any` → `Utils.concat_any([children...])`
4. Top-level nodes are implicitly combined with `concat_all` (AND logic)

### Execution Model

Unlike Ord DSL, Eq DSL has no implicit identity tiebreaker. An empty `eq` block compiles to an identity Eq that considers all values equal.

Each directive compiles to:

* `on` → `contramap(projection, eq)`
* `diff_on` → `contramap(projection, negated_eq)`
* `all` → `concat_all([children...])`
* `any` → `concat_any([children...])`

### Type-Specific Code Generation

The executor uses the `type` field from Steps to generate specific code paths, eliminating runtime branching and compiler warnings:

* `:projection` - Direct contramap with projection
* `:module_eq` - Convert module via `to_eq_map` then use
* `:eq_map` - Use Eq map directly (from Behaviour)
* `:dynamic` - Runtime case statement to detect type

### Negation (diff_on)

The `diff_on` directive swaps the `eq?/not_eq?` functions to check for inequality. This is implemented by creating a negated Eq map:

```elixir
negated_eq = %{
  eq?: original.not_eq?,
  not_eq?: original.eq?
}
```

Important: Using `diff_on` breaks transitivity and creates an Extended Eq that is not an equivalence relation. Do not use with grouping operations like `Funx.List.uniq/2` or `MapSet`.

### Compilation Example

```elixir
eq do
  on :name
  on :age
  any do
    on :email
    on :username
  end
end
```

Compiles to:

```elixir
Utils.concat_all([
  Utils.contramap(Prism.key(:name), Funx.Eq),
  Utils.contramap(Prism.key(:age), Funx.Eq),
  Utils.concat_any([
    Utils.contramap(Prism.key(:email), Funx.Eq),
    Utils.contramap(Prism.key(:username), Funx.Eq)
  ])
])
```

## Behaviours

Modules participating in the Eq DSL implement `Funx.Eq.Dsl.Behaviour`. The parser detects behaviour modules and calls their `eq/1` callback, which must return an Eq map (not a projection).

The `eq/1` callback receives:

* `opts` - Keyword list of options passed in the DSL (e.g., `on MyBehaviour, threshold: 0.5`)

Example:

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

  defp string_similarity(a, b) do
    # Implementation here
  end
end

eq do
  on FuzzyStringEq, threshold: 0.9
end
```

The executor uses the returned Eq map directly (type `:eq_map`), avoiding the need to wrap it in `contramap`.

## Equivalence Relations and diff_on

The Eq DSL supports two modes:

### Core Eq (Equivalence Relations)

Using only `on`, `all`, and `any` creates a Core Eq that forms an equivalence relation:

* Reflexive: `eq?(a, a)` is always true
* Symmetric: If `eq?(a, b)` then `eq?(b, a)`
* Transitive: If `eq?(a, b)` and `eq?(b, c)` then `eq?(a, c)`

Core Eq safely partitions values into equivalence classes, making it suitable for:

* `Funx.List.uniq/2` - Remove duplicates
* `MapSet` - Set membership
* `Enum.group_by/2` - Grouping operations

### Extended Eq (Boolean Predicates)

Using `diff_on` creates an Extended Eq that expresses boolean equality predicates but does not guarantee transitivity.

Example transitivity violation:

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

Even though `a == b` and `b == c`, we have `a != c`, violating transitivity.

Rule: If you need equivalence classes, do not use `diff_on`. Use it only for boolean predicates where transitivity is not required.
