# Overview

Funx provides two distinct categories of DSLs with different purposes and semantics.

## DSL Categories

### Builder DSLs

Builder DSLs construct data structures (comparators, orderings, predicates) for later use.

Examples: `eq`, `ord`, `pred`

Characteristics:

- No input parameter — builds a reusable function or comparator
- Returns a data structure — built via monoidal composition (Eq.All, Ord monoid, predicate function)
- Used with utility functions — `Eq.eq?/3`, `Ord.compare/3`, `Enum.filter/2`
- May support nesting — `any`/`all` blocks for boolean composition (Eq, Pred only)

Example:

```elixir
# Build a comparator
user_eq = eq do
  on :name
  on :email
end

# Use it later
Eq.eq?(user1, user2, user_eq)
```

### Pipeline DSLs

Pipeline DSLs execute a sequence of operations on an input value.

Examples: `maybe`, `either`

Characteristics:

- Takes input parameter — transforms/validates the input
- Returns a result — Maybe.t() or Either.t() with the transformed value
- Sequential execution — steps run in order, short-circuit on failure
- Supports transformers — compile-time pipeline optimization

Example:

```elixir
# Execute pipeline on input
maybe user_id do
  bind GetUser
  bind ValidateActive
  map FormatResponse
end
# Returns Maybe.t()
```

### Key Differences

| Aspect      | Builder DSLs                | Pipeline DSLs             |
| ----------- | --------------------------- | ------------------------- |
| Signature   | `dsl do ... end`            | `dsl input do ... end`    |
| Purpose     | Build reusable structures   | Transform input values    |
| Execution   | Deferred (used later)       | Immediate (on input)      |
| Return Type | Monoid/Function             | Monad (Maybe/Either)      |
| Nesting     | Supports `any`/`all` blocks | Linear (sequential steps) |

## Structure

A Funx DSL block compiles at macro-expansion time. The compiler parses the block syntax, applies transformations, and produces executable code. The compiled representation varies by DSL but typically involves structured data describing the operations to perform.

```text
Compilation
    ├── DSL Block (AST)
    ├── Parser
    │     └── Builds internal representation
    ├── Transformers
    │     └── Optional rewrites
    ├── Compiled Form
    └── Executor
          └── Produces result
```

## Operations

Each DSL defines its own internal representation of operations. For pipeline DSLs, these are typically step structs describing transformations. For builder DSLs, operations describe composition rules. The executor interprets these representations to produce the final result.

```text
Parsed Operations
    ├── Operation
    ├── Operation
    ├── Operation
    └── Operation
```

## Parser

Each DSL provides its own parser. The parser converts the DSL block into an internal representation, applies lifting and alias-expansion rules, and raises compile-time errors for invalid or unsupported forms.

## Transformers

Transformers run during compilation and may rewrite the parsed operations before code generation. They can insert, remove, or modify operations. A transformer must return a valid representation for that DSL and introduces a compile-time dependency. Currently supported by pipeline DSLs (Maybe, Either).

## Execution

Each DSL has a dedicated executor. The executor interprets the compiled representation and produces the final result. It does not inspect source code; it operates only on the compiled form.

## Behaviours

Each DSL defines a behaviour for modules that participate in the DSL. Modules implementing this behaviour supply the callback the executor invokes. The DSL determines how the callback's return value is interpreted.

## Architectural Choices

### Why Ord Doesn't Support Nesting

The `ord` DSL does not support `any`/`all` blocks like `eq` and `pred` do. This is intentional.

Total orderings compose linearly. When you combine orderings with `Ord.concat/1`, you get a lexicographic ordering where the first comparison that returns `:lt` or `:gt` determines the result. This is fundamentally different from the boolean logic of equality or predicates.

```elixir
# Ord: Linear composition (lexicographic)
ord do
  asc :last_name   # First comparison
  asc :first_name  # Tiebreaker if last names equal
  desc :age        # Further tiebreaker
end

# Eq: Can express OR logic
eq do
  any do
    on :email
    on :username
  end
end
```

There's no meaningful "OR" for orderings - you can't say "order by name OR age". The order is always determined by a sequence of tiebreakers.

### Why Pipeline DSLs Don't Support Nesting

Pipeline DSLs (`maybe`, `either`) execute sequentially and short-circuit on failure. They don't support `any`/`all` blocks because monadic composition is inherently sequential — each operation depends on the result of the previous one. There's no boolean combination to express; operations either succeed (Right/Just) or fail (Left/Nothing), and failure stops the pipeline.

For conditional logic in pipelines, use the monad's native operations:

- `filter` - conditionally keep/drop values
- `guard` - assert a condition
- Pattern matching in behaviour callbacks
