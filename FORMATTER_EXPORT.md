# Funx Formatter Configuration Export

## What This Does

The Funx library now exports formatter rules for its Either DSL, allowing projects that depend on Funx to automatically format DSL code without extra parentheses.

## Exported Rules

The following Either DSL functions are configured to format without parentheses:

- `either/2` - DSL entry point
- `bind/1` - Chain operations that return Either or result tuples
- `map/1` - Transform values with plain functions
- `ap/1` - Apply function in Either to value in Either
- `validate/1` - Collect all errors from validators
- `filter_or_else/2` - Filter with predicate, fallback if fails
- `or_else/1` - Provide fallback on error
- `map_left/1` - Transform error values

Note that `flip/0` - Swap Left and Right still requires parentheses.

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

### Step 3: Remove Manual Configuration (if present)

If you previously had manual configuration like this:

```elixir
[
  locals_without_parens: [
    bind: 1,
    map: 1
  ]
]
```

You can now **remove it** - the rules will be automatically imported from Funx.

## Example

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

## Verification

To verify the formatter rules are being imported correctly, you can run:

```bash
mix format --check-formatted
```

Your DSL code should format without adding parentheses.
