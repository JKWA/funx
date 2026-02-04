# Formatter Rules

The Funx library exports formatter rules for its DSLs, allowing projects that depend on Funx to automatically format DSL code without extra parentheses.

## Exported Rules

### Either DSL

The following Either DSL functions are configured to format without parentheses:

- `either/2` - DSL entry point
- `bind/1` - Chain operations that return Either or result tuples
- `map/1` - Transform values with plain functions
- `ap/1` - Apply function in Either to value in Either
- `validate/1` - Collect all errors from validators
- `filter_or_else/2` - Filter with predicate, fallback if fails
- `or_else/1` - Provide fallback on error
- `map_left/1` - Transform error values
- `tap` - Run a side-effecting function inside the chain without changing the data

Note that `flip/0` - Swap Left and Right still requires parentheses.

### Maybe DSL

The following Maybe DSL functions are configured to format without parentheses:

- `maybe/2` - DSL entry point
- `bind/1` - Chain operations that return Maybe, Either, result tuples, or nil (shared with Either DSL)
- `map/1` - Transform values with plain functions (shared with Either DSL)
- `ap/1` - Apply function in Maybe to value in Maybe (shared with Either DSL)
- `or_else/1` - Provide fallback on Nothing (shared with Either DSL)
- `tap/1` - Run a side-effecting function inside the chain without changing the data (shared with Either DSL)
- `filter/1` - Filter with a predicate, returns Nothing if predicate fails
- `filter_map/2` - Filter and transform in one step
- `guard/1` - Guard with a boolean condition

### Ord DSL

The following Ord DSL functions are configured to format without parentheses:

- `asc/1` - Ascending order for a projection
- `asc/2` - Ascending order with options (e.g., `default:`)
- `desc/1` - Descending order for a projection
- `desc/2` - Descending order with options (e.g., `default:`)

### Eq DSL

The following Eq DSL functions are configured to format without parentheses:

- `on/1` - Compare on a projection
- `on/2` - Compare on a projection with options
- `not_on/1` - Exclude a projection from comparison
- `not_on/2` - Exclude a projection from comparison with options
- `any/1` - Match any of the given comparisons (shared with Predicate DSL)
- `all/1` - Match all of the given comparisons (shared with Predicate DSL)

### Predicate DSL

The following Predicate DSL functions are configured to format without parentheses:

- `pred/1` - DSL entry point for defining predicates
- `check/1` - Project and default truthy (e.g., `check :field`)
- `check/2` - Project and test a value (e.g., `check :field, predicate`)
- `negate/1` - Negate a predicate or block
- `negate_all/1` - Negate an AND block (applies De Morgan's Laws)
- `negate_any/1` - Negate an OR block (applies De Morgan's Laws)
- `any/1` - OR logic - at least one predicate must pass (shared with Eq DSL)
- `all/1` - AND logic - all predicates must pass (shared with Eq DSL)

## Usage in Dependent Projects

### Step 1: Add to Dependencies

Make sure your `mix.exs` includes Funx as a dependency:

```elixir
def deps do
  [
    {:funx, "~> 0.2"}
  ]
end
```

### Step 2: Update .formatter.exs

In your project's `.formatter.exs`, add `:funx` to `import_deps`:

```elixir
[
  import_deps: [:funx],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

## Examples

### Either DSL

With this configuration, your DSL code will format cleanly:

```elixir
either user_input do
  bind ParseUser
  map ValidateEmail
  validate [CheckLength, CheckFormat]
  bind SaveToDatabase
  or_else default_user()
end
```

Instead of:

```elixir
either(user_input) do
  bind(ParseUser)
  map(ValidateEmail)
  validate([CheckLength, CheckFormat])
  bind(SaveToDatabase)
  or_else(default_user())
end
```

### Maybe DSL

Your Maybe pipelines will format cleanly:

```elixir
maybe user_input do
  bind ParseInt
  filter PositiveNumber
  map Double
  or_else default_value()
end
```

Instead of:

```elixir
maybe(user_input) do
  bind(ParseInt)
  filter(PositiveNumber)
  map(Double)
  or_else(default_value())
end
```

### Ord DSL

Your ordering definitions will format cleanly:

```elixir
ord do
  asc :name
  desc :age
  asc :score, default: 0
end
```

Instead of:

```elixir
ord do
  asc(:name)
  desc(:age)
  asc(:score, default: 0)
end
```

### Predicate DSL

Your predicate definitions will format cleanly:

```elixir
pred do
  check :age, fn age -> age >= 18 end
  negate check :banned, fn b -> b == true end
  any do
    check :role, fn r -> r == :admin end
    check :verified, fn v -> v == true end
  end
  negate_all do
    check :suspended, fn s -> s == true end
    check :deleted, fn d -> d == true end
  end
end
```

Instead of:

```elixir
pred do
  check(:age, fn age -> age >= 18 end)
  negate(check(:banned, fn b -> b == true end))
  any do
    check(:role, fn r -> r == :admin end)
    check(:verified, fn v -> v == true end)
  end
  negate_all do
    check(:suspended, fn s -> s == true end)
    check(:deleted, fn d -> d == true end)
  end
end
```

## Verification

To verify the formatter rules are being imported correctly, you can run:

```bash
mix format --check-formatted
```

Your DSL code should format without adding parentheses.
