# `Funx.Utils` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Currying**: Converting a multi-argument function into a chain of single-argument functions

- `curry_r/1`: Curries arguments from right to left, allowing data argument to be applied last (pipeline-friendly)
- `curry/1` & `curry_l/1`: Left-to-right currying (traditional functional style)
- Example: `f(a, b, c)` → `curry(f).(a).(b).(c)`
- **Edge case**: Currying a unary function returns the original function (no-op)

**Partial Application**: Fixing some arguments of a function, creating a new function

- Result of currying: each step returns a function waiting for remaining args
- Enables configuration-first, data-last patterns
- Example: `add = curry_r(+).(5)` creates function that adds 5

**Point-Free Style**: Writing functions without explicitly mentioning arguments

- Compose functions without intermediate variables
- More declarative and reusable
- Example: `process = transform |> validate |> save`

**Function Flipping**: Reversing argument order for better composition

- `flip/1`: Swaps arguments of binary functions (arity = 2 only)
- Useful when argument order doesn't match pipeline needs
- Example: `flip(div).(2, 10)` → `10 / 2`
- **Invalid**: `flip/1` cannot be applied to unary or 3+ arity functions

**Arity Independence**: Works with functions of any number of arguments

- Dynamically inspects function arity via `:erlang.fun_info/2`
- Returns as many nested unary functions as the original function has parameters
- No need to know function arity in advance - curry supports arbitrary arity

## LLM Decision Guide: When to Use Utils

**✅ Use Utils when:**

- Building reusable, composable functions
- Need partial application for configuration
- Want point-free programming style
- Adapting functions for pipeline use
- User says: "configure then apply", "reuse with different parameters", "point-free"

**❌ Don't use Utils when:**

- Simple one-off function calls
- Performance is absolutely critical
- Argument order is already correct
- Functions are already curried

**⚡ Currying Strategy Decision:**

- **Pipeline-friendly**: Use `curry_r/1` (data flows left-to-right, config right-to-left)
- **Traditional FP**: Use `curry/1` or `curry_l/1` (left-to-right application)
- **Argument reordering**: Use `flip/1` then curry as needed

**⚙️ Function Choice Guide (Mathematical Purpose):**

- **Configuration before data**: `curry_r(fn config, data -> ... end).(config)`
- **Traditional currying**: `curry(fn a, b, c -> ... end).(a).(b).(c)`
- **Argument order fix**: `flip(fn a, b -> ... end)`
- **Point-free composition**: Combine curried functions without variables

## LLM Context Clues

**User language → Utils patterns:**

- "configure then apply" → `curry_r` for config-first pattern
- "reuse with different settings" → curry for partial application
- "flip the arguments" → `flip/1`
- "point-free style" → curry functions for composition
- "pipeline-friendly" → `curry_r/1`
- "traditional currying" → `curry/1` or `curry_l/1`

## Quick Reference

- Use `curry_r/1` to curry functions right-to-left—ideal for Elixir's `|>` pipe style.
- Use `curry/1` or `curry_l/1` to curry left-to-right when needed.
- Use `flip/1` to reverse arguments in binary functions.
- All currying functions adapt to any arity and return nested unary functions.

## Overview

`Funx.Utils` provides functional utilities for reshaping multi-argument functions to support composition, partial application, and point-free style.
Use `curry_r/1` by default—it aligns with Elixir’s `|>` operator by shifting configuration to the right and leaving the data position first.

These tools are especially useful with predicates, monads, and other combinators where composition and reuse are key.

## Composition Rules

| Function    | Description                                                  |
| ----------- | ------------------------------------------------------------ |
| `curry_r/1` | Curries a function right-to-left (recommended for pipelines) |
| `curry/1`   | Curries left-to-right                                        |
| `curry_l/1` | Alias for `curry/1`, makes intent explicit                   |
| `flip/1`    | Reverses arguments of a binary function                      |

Each function returns a chain of unary functions that accumulate arguments until fully applied.

## Usage Patterns

### Right-to-Left Currying for Pipelines

```elixir
f = fn prefix, name -> prefix <> name end
greet = curry_r(f).("Hello, ")
"Alice" |> greet()
# => "Hello, Alice"
```

### Flip for Reordering Binary Functions

```elixir
div = fn a, b -> a / b end
flipped = flip(div)
flipped.(2, 10)  # => 5.0
```

### Left-to-Right Currying (Less Common)

```elixir
sum = curry(fn a, b, c -> a + b + c end)
sum.(1).(2).(3)  # => 6
```

## Guidelines for Composition

Follow these patterns when reshaping or generating function transformations:

- Prefer `curry_r/1` for functions that appear in pipelines.
- Use `flip/1` when argument order doesn’t match surrounding context.
- Use `curry/1` or `curry_l/1` when left-to-right application is more natural.
- Avoid manual `fn` nesting—use the provided helpers instead.
- Avoid assuming a function has only 2 or 3 arguments—curry_r/1 supports arbitrary arity and returns as many nested unary functions as needed.
- Avoid capture syntax (`&mod.fun/arity`) when partial application is needed.
  Capture locks arity and order, and cannot be curried or reordered.

Currying is often most useful when composed with lifted combinators like `map`, `bind`, `filter`, and so on.

## Stability Contract

Ensure that generated or transformed functions preserve:

- Purity — returned functions are referentially transparent.
- Laziness — arguments are applied only when provided.
- Equivalence — full application matches the original function:

```elixir
curry_r(f).(b).(a) == f.(a, b)
```

## Anti-Patterns

Avoid generating or emitting:

- Manual currying via nested `fn` chains: `fn a -> fn b -> f.(a, b) end end`
- Assuming functions have fixed arity (curry supports arbitrary arity dynamically)
- Argument reordering by hand—prefer `flip/1`
- Full application immediately after currying
- Capture syntax (`&fun/2`) when transformation is required

## Good Patterns

Encourage completions like:

```elixir
# Partial right-to-left application for pipelines
assign_role = curry_r(fn role, user -> %{user | role: role} end)
user |> assign_role.("admin")
```

```elixir
# Flipping to enable higher-order composition
compare = flip(fn a, b -> a > b end)
Enum.filter(list, compare.(10))
```

```elixir
# Contextual function with partial application
transform =
  curry_r(fn format, name -> format.("<" <> name <> ">") end)
"Alex" |> transform.(&String.upcase/1)
```

## When to Use

Reach for these utilities when you want to:

- Enable point-free style
- Compose partial functions within a pipeline
- Shift configuration before data
- Adapt argument order to match surrounding combinators
- Prepare functions before lifting into a monadic or applicative context

## Built-in Behavior

- `curry_r/1`, `curry/1`, and `curry_l/1` inspect function arity via `:erlang.fun_info/2`.
- Returned functions accumulate arguments until fully applied.
- `flip/1` applies only to functions of arity 2.

## LLM Code Templates

### Configuration-First Pattern Template

```elixir
# API client with configurable base settings
def build_api_client() do
  request_fn = curry_r(fn headers, auth, url ->
    HTTPoison.get(url, headers, auth: auth)
  end)
  
  # Pre-configure common settings
  authenticated_request = request_fn
    |> apply.([{"Content-Type", "application/json"}])
    |> apply.({:bearer, "token"})
  
  # Now just pass URLs
  "/users" |> authenticated_request.()
  "/posts" |> authenticated_request.()
end
```

### Data Transformation Pipeline Template

```elixir
def build_transformer() do
  # Curry transformation functions for reuse
  validate_with = curry_r(fn rules, data ->
    if Enum.all?(rules, fn rule -> rule.(data) end) do
      {:ok, data}
    else
      {:error, "validation failed"}
    end
  end)
  
  transform_with = curry_r(fn mapper, {:ok, data} -> {:ok, mapper.(data)} end)
  
  # Build reusable pipelines
  user_rules = [&is_adult/1, &has_email/1]
  user_validator = validate_with.(user_rules)
  user_transformer = transform_with.(&normalize_user/1)
  
  # Apply to data
  user_data 
  |> user_validator.()
  |> user_transformer.()
end
```

### Function Composition Template

```elixir
def build_processors() do
  # Flip functions to match pipeline argument order
  filter_by = flip(&Enum.filter/2)
  map_with = flip(&Enum.map/2)
  reduce_by = curry_r(&Enum.reduce/3)
  
  # Create specialized processors
  filter_adults = filter_by.(fn user -> user.age >= 18 end)
  extract_names = map_with.(fn user -> user.name end)
  count_items = reduce_by.(0, fn _, acc -> acc + 1 end)
  
  # Compose into pipeline
  users
  |> filter_adults.()
  |> extract_names.()
  |> count_items.()
end
```

### Predicate Factory Template

```elixir
def build_predicates() do
  # Create configurable predicates
  field_equals = curry_r(fn value, field, item ->
    Map.get(item, field) == value
  end)
  
  field_greater = curry_r(fn threshold, field, item ->
    Map.get(item, field) > threshold
  end)
  
  # Generate specific predicates
  is_admin = field_equals.(:admin, :role)
  is_adult = field_greater.(18, :age)
  is_active = field_equals.(true, :active)
  
  # Use with filtering
  users |> Enum.filter(is_admin)
  users |> Enum.filter(is_adult)
end
```

## LLM Performance Considerations

**Currying overhead:**

- Each curried function call has slight overhead
- Consider performance impact for hot paths
- Pre-curry functions used repeatedly

**Memory considerations:**

- Curried functions capture arguments in closures
- Can prevent garbage collection of captured values
- Use judiciously in long-running processes

**Thread-safety for closures:**

- Curried closures may capture config values
- In long-running processes, ensure captured values don't include large, stateful, or cyclic data
- Captured values should be immutable and reasonably sized

**Optimization patterns:**

```elixir
# ✅ Good: curry once, use many times
transformer = curry_r(&String.replace/3).("old", "new")
results = Enum.map(strings, transformer)

# ❌ Less efficient: curry in loop
results = Enum.map(strings, fn s -> 
  curry_r(&String.replace/3).("old", "new").(s)
end)
```

## LLM Interop Patterns

### With Enum Functions

```elixir
# Make Enum functions pipeline-friendly
map_with = flip(&Enum.map/2)
filter_by = flip(&Enum.filter/2)
reduce_by = curry_r(&Enum.reduce/3)

# Use in pipelines
data
|> filter_by.(predicate)
|> map_with.(transformer)
|> reduce_by.(initial_value, accumulator)
```

### With GenServer Calls

```elixir
# Create configured GenServer callers
def build_service_client(server_name) do
  call_server = curry_r(&GenServer.call/2).(server_name)
  cast_server = curry_r(&GenServer.cast/2).(server_name)
  
  %{
    get_user: call_server.({:get_user, user_id}),
    update_user: cast_server.({:update_user, user_data}),
    delete_user: cast_server.({:delete_user, user_id})
  }
end
```

### With Phoenix Contexts

```elixir
# Create context function factories
def build_user_operations(repo) do
  create_with_repo = curry_r(fn changeset, repo ->
    Repo.insert(changeset, repo: repo)
  end).(repo)
  
  update_with_repo = curry_r(fn changeset, user, repo ->
    Repo.update(changeset, repo: repo)
  end).(repo)
  
  %{
    create_user: create_with_repo,
    update_user: update_with_repo
  }
end
```

## LLM Testing Guidance

### Test Currying Behavior

```elixir
test "curry_r creates proper function chain" do
  add3 = fn a, b, c -> a + b + c end
  curried = Funx.Utils.curry_r(add3)
  
  # Test partial application
  partial1 = curried.(3)
  partial2 = partial1.(2)
  result = partial2.(1)
  
  assert result == 6
  assert add3.(1, 2, 3) == curried.(3).(2).(1)
end

test "curry_l creates left-to-right chain" do
  multiply3 = fn a, b, c -> a * b * c end
  curried = Funx.Utils.curry(multiply3)
  
  result = curried.(2).(3).(4)
  assert result == 24
end
```

### Test Function Flipping

```elixir
test "flip reverses binary function arguments" do
  subtract = fn a, b -> a - b end
  flipped = Funx.Utils.flip(subtract)
  
  assert subtract.(10, 3) == 7
  assert flipped.(3, 10) == 7
end
```

### Test Point-Free Composition

```elixir
test "curried functions compose for point-free style" do
  transform = Funx.Utils.curry_r(fn suffix, prefix, text ->
    prefix <> text <> suffix
  end)
  
  add_brackets = transform.("]", "[")
  add_parens = transform.(")", "(")
  
  assert add_brackets.("test") == "[test]"
  assert add_parens.("test") == "(test)"
end
```

## LLM Debugging Tips

### Test Individual Steps

```elixir
# Debug currying by testing each step
add3 = fn a, b, c -> a + b + c end
curried = curry_r(add3)

step1 = curried.(3)
IO.inspect(step1, label: "after first arg")

step2 = step1.(2) 
IO.inspect(step2, label: "after second arg")

result = step2.(1)
IO.inspect(result, label: "final result")
```

### Verify Equivalence

```elixir
# Ensure curried version equals original
original_result = original_fn.(arg1, arg2, arg3)
curried_result = curry_r(original_fn).(arg3).(arg2).(arg1)
assert original_result == curried_result
```

## LLM Error Message Design

### Handle Arity Mismatches

```elixir
def safe_curry(fun) do
  case :erlang.fun_info(fun, :arity) do
    {:arity, 0} -> {:error, "Cannot curry zero-arity function"}
    {:arity, n} when n > 0 -> {:ok, Funx.Utils.curry_r(fun)}
    _ -> {:error, "Invalid function"}
  end
end
```

### Provide Clear Function Descriptions

```elixir
def build_transformer(name, transform_fn) do
  curried = Funx.Utils.curry_r(transform_fn)
  
  # Add metadata for debugging
  fn config ->
    fn data ->
      try do
        curried.(config).(data)
      rescue
        error -> 
          {:error, "#{name} transformation failed: #{inspect(error)}"}
      end
    end
  end
end
```

## LLM Common Mistakes to Avoid

**❌ Don't use capture syntax with currying**

```elixir
# ❌ Wrong: capture syntax can't be curried
curry_r(&String.replace/3)

# ✅ Correct: use explicit function
curry_r(fn str, old, new -> String.replace(str, old, new) end)
```

**❌ Don't assume argument order**

```elixir
# ❌ Wrong: assuming curry_r argument order
divide = curry_r(fn a, b -> a / b end)
result = divide.(10).(2)  # This gives 0.2, not 5

# ✅ Correct: be explicit about order
divide = curry_r(fn divisor, dividend -> dividend / divisor end)
result = divide.(2).(10)  # This gives 5
```

**❌ Don't curry already curried functions**

```elixir
# ❌ Wrong: double currying
double_curried = curry_r(curry_r(fn a, b -> a + b end))

# ✅ Correct: curry once
curried = curry_r(fn a, b -> a + b end)
```

**❌ Don't ignore arity requirements**

```elixir
# ❌ Wrong: flip only works on binary functions
flip(fn a, b, c -> a + b + c end)  # Will error

# ✅ Correct: use flip only on binary functions
flip(fn a, b -> a + b end)
```

## Summary

`Funx.Utils` enables functional composition through currying and argument manipulation. Use it to build reusable, configurable functions that compose naturally in pipelines.

- **Right-to-left currying**: Use `curry_r/1` for Elixir pipeline style (data-last)
- **Left-to-right currying**: Use `curry/1` or `curry_l/1` for traditional functional style
- **Argument flipping**: Use `flip/1` to adapt binary functions for better composition
- **Point-free style**: Eliminate intermediate variables through function composition
- **Partial application**: Pre-configure functions with some arguments, apply data later
- **Arity independence**: Works with functions of any number of arguments dynamically
