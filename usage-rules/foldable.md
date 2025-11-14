# `Funx.Foldable` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Foldable**: Protocol for collapsing any structure into a single value using conditional logic

- **`fold_l/3`**: Universal fold operation with present/absent function handling
- **`fold_r/3`**: Right-associative fold (same as fold_l for branching structures)
- **Polymorphic folding**: Same interface, different implementations based on structure type
- **Generic abstraction**: Folding is the universal pattern for "structure → single value"

**Core Pattern**: `fold(structure, present_func, absent_func)`

- **present_func**: Function called when structure contains value(s) 
- **absent_func**: Function called when structure is empty/absent
- **Result**: Single collapsed value from conditional logic

**Universal Folding Concept**: Every time you handle "what do I have, do different things based on that", you're conceptually folding. The protocol makes this pattern explicit and composable.

## LLM Decision Guide: When to Use Foldable

**✅ Use Foldable when:**

- Need to extract a concrete value from wrapped context (Maybe, Either)
- Collapsing collections into summary values
- Providing default values for empty/missing cases  
- Exit strategy from monadic pipelines back to concrete values
- **Prefer over imperative conditionals** (`case`, `cond`, `if/else`) for composability
- **Prefer over `Enum.reduce/3`** when working with potentially empty structures
- User says: "default value", "extract from", "handle both cases", "reconcile branches"

**⚡ Folding Strategy Decision:**

- **Context reconciliation** (Maybe/Either): Exit point from monadic pipeline
- **Collection aggregation** (List): Standard reduce/accumulation pattern  
- **Default provision**: Provide fallbacks for empty/missing cases
- **Branch handling**: Functional alternative to imperative case/cond logic

**⚙️ Function Choice Guide:**

- **Simple default values**: Use `Maybe.get_or_else/2` or `Either.get_or_else/2` instead of manual fold
- **Complex pipeline exit**: `fold_l(either_result, &success_handler/1, &error_handler/0)`
- **Collection summary**: `fold_l(list, &Enum.sum/1, fn -> 0 end)`
- **Direction choice**: Use `fold_l` as standard; `fold_r` only for ordered collections needing right-associative processing

## LLM Context Mapping

**User Intent → Foldable Patterns:**

- "get value or default" → `Maybe.get_or_else(maybe, default)` or `Either.get_or_else(either, default)`
- "handle success and error" → `fold_l(either, &process_success/1, &handle_error/0)`
- "extract from Maybe" → Use `Maybe.get_or_else/2` for simple cases, fold for complex transformations
- "sum all or zero" → `fold_l(list, &Enum.sum/1, fn -> 0 end)`
- "collapse pipeline result" → Use fold as final step to exit monadic context

## Overview

`Funx.Foldable` is a protocol that provides **polymorphic folding** - the universal pattern for collapsing any structure into a single value through conditional logic.

## Core Insight: Folding is Everywhere

Developers fold constantly without realizing it:

```elixir
# Pattern matching tagged tuples = folding
case fetch_user(id) do
  {:ok, user} -> user.name        # present_func
  {:error, _} -> "Unknown"        # absent_func  
end

# List reduction = folding
Enum.reduce([1, 2, 3], 0, &+/2)   # Standard fold/reduce

# Conditional logic = folding boolean structure
if user do
  process(user)                   # present_func
else
  handle_missing()                # absent_func
end
```

**Foldable makes this pattern explicit and composable** through protocol-based polymorphism.

## Functional Programming Preference

**In functional programming with Funx, prefer fold over:**

- **Imperative conditionals**: `case`, `cond`, `if/else` statements  
- **Elixir's `Enum.reduce/3`**: When working with structures that might be empty
- **Manual pattern matching**: Scattered conditional logic throughout code

**Why fold is better:**
- **Composable**: Works in pipelines and with other functional operations
- **Polymorphic**: Same interface across different data types
- **Consistent**: Unified approach to conditional logic
- **Safe**: Always handles both present and absent cases explicitly

## The Universal Folding Concept

**Generic Pattern**: `Structure + Logic → Single Value`

**Structure-Specific Implementations**:
- **Lists**: Traversal + accumulation (using Erlang's `:lists.foldl/3`)
- **Maybe/Either**: Conditional branching (present vs absent logic)
- **Predicates**: Evaluation + branching (true/false cases)
- **Tagged tuples**: Success/error reconciliation

**Same mental model everywhere**: "I have a structure, I want one value, here's logic for both cases."

## Core Operations

### `fold_l/3` - Universal Fold Operation

Collapses any structure using conditional functions:

```elixir
import Funx.Foldable

# Maybe: Extract with default
fold_l(Maybe.just(42), fn x -> x * 2 end, fn -> 0 end)  # 84
fold_l(Maybe.nothing(), fn x -> x * 2 end, fn -> 0 end)  # 0

# Either: Success/error handling  
fold_l(Either.right("data"), &String.upcase/1, fn -> "DEFAULT" end)  # "DATA"
fold_l(Either.left("error"), &String.upcase/1, fn -> "DEFAULT" end)   # "DEFAULT"

# List: Collection aggregation
fold_l([1, 2, 3], &Enum.sum/1, fn -> 0 end)  # 6
fold_l([], &Enum.sum/1, fn -> 0 end)         # 0
```

**Use `fold_l` for:**

- Extracting concrete values from wrapped contexts
- Providing defaults for empty cases
- Pipeline exit points (monadic context → concrete value)
- Standard choice for all folding operations

### `fold_r/3` - Right-Associative Fold

Right-associative folding for ordered collections:

```elixir
import Funx.Foldable

# For branching structures, direction is irrelevant
fold_r(Maybe.just(42), fn x -> x * 2 end, fn -> 0 end)  # 84 (same as fold_l)

# For ordered collections, direction affects traversal
fold_r([1, 2, 3], &build_right/2, fn -> initial end)  # Right-to-left processing
```

**Use `fold_r` when:**

- Working with ordered collections requiring right-associative folding
- Specific algorithmic needs for traversal direction
- **Note**: Identical to `fold_l` for branching structures (Maybe, Either, predicates)

## Folding Types: Two Categories

### 1. Branching Structures (Context Reconciliation)

**Purpose**: Exit strategy from monadic contexts

```elixir
# Maybe folding - handle presence/absence
def get_user_display_name(maybe_user) do
  fold_l(maybe_user, fn user -> user.name end, fn -> "Anonymous" end)
end

# Either folding - success/error reconciliation  
def process_api_result(either_result) do
  fold_l(
    either_result,
    fn success_data -> format_success(success_data) end,
    fn -> "Operation failed" end
  )
end

# Predicate folding - conditional execution
def branch_on_condition(predicate_fn) do
  fold_l(
    predicate_fn,
    fn -> "Condition met" end,      # If predicate returns true
    fn -> "Condition not met" end   # If predicate returns false
  )
end
```

**Characteristics**:
- **Direction irrelevant** - no traversal, just conditional logic
- **Present/absent semantics** 
- **Type reconciliation** from wrapped to concrete values
- **Pipeline exit points**

### 2. Ordered Collections (Aggregation/Reduction)

**Purpose**: Standard reduce operations using Erlang's fold functions

```elixir
# List aggregation
def safe_sum(list) do
  fold_l(list, fn items -> Enum.sum(items) end, fn -> 0 end)
end

# Collection statistics
def calculate_average(numbers) do
  fold_l(
    numbers,
    fn nums -> Enum.sum(nums) / length(nums) end,
    fn -> 0.0 end
  )
end

# First element with default
def first_or_default(list, default) do
  fold_l(list, fn [head | _] -> head end, fn -> default end)
end
```

**Characteristics**:
- **Direction matters** - left-to-right vs right-to-left processing
- **Accumulator patterns** - building up results
- **Uses Erlang's `:lists.foldl/3` and `:lists.foldr/3`**
- **Performance considerations** for large collections

## Common Folding Patterns

### 1. Pipeline Exit Pattern

**Problem**: Need concrete value from monadic pipeline
**Solution**: Use fold as final step

```elixir
# Manage control logic within pipeline, extract at end
result = 
  user_id
  |> fetch_user()                    # Maybe User - handles not found
  |> bind(&validate_permissions/1)   # Maybe User - handles validation
  |> map(&get_dashboard_data/1)      # Maybe Dashboard - transforms if valid
  |> filter(&has_recent_activity?/1) # Maybe Dashboard - conditional retention
  # All control logic managed within Maybe context ↑
  
  # Extract concrete value at pipeline boundary ↓
  |> fold_l(
      fn dashboard -> render_dashboard(dashboard) end,  # success path
      fn -> render_login_prompt() end                   # any failure path
    )
```

### 2. Default Value Pattern

**Problem**: Need fallbacks for missing/empty values
**Solution**: Use convenience functions for simple cases, fold for complex cases

```elixir
# ✅ Simple default - use convenience functions
def with_simple_default(maybe_value, default) do
  Maybe.get_or_else(maybe_value, default)
end

def with_simple_either_default(either_value, default) do
  Either.get_or_else(either_value, default)
end

# ✅ Complex transformations - use fold
def with_complex_transformation(maybe_value) do
  fold_l(
    maybe_value, 
    fn value -> transform_and_process(value) end,
    fn -> expensive_computation() end
  )
end

# Chained fallbacks
def first_available(maybes) when is_list(maybes) do
  Enum.reduce(maybes, Maybe.nothing(), fn maybe, acc ->
    fold_l(acc, &Maybe.just/1, fn -> maybe end)
  end)
end
```

### 3. Tagged Tuple Reconciliation Pattern

**Problem**: Handle `{:ok, value}` / `{:error, reason}` results
**Solution**: Convert to Either, then fold

```elixir
def handle_api_call(params) do
  params
  |> make_api_request()              # {:ok, data} | {:error, reason}
  |> Either.from_tagged()            # Either.Right | Either.Left
  |> fold_l(
      fn data -> process_success(data) end,
      fn -> handle_api_error() end
    )
end
```

### 4. Collection Aggregation Pattern

**Problem**: Safely aggregate collections that might be empty
**Solution**: Use fold with aggregation and default functions

```elixir
# Safe mathematical operations
def safe_average(numbers) when is_list(numbers) do
  case numbers do
    [] -> fold_l(Maybe.nothing(), &Function.identity/1, fn -> 0.0 end)
    nums -> fold_l(Maybe.just(nums), fn ns -> Enum.sum(ns) / length(ns) end, fn -> 0.0 end)
  end
end

# Resource utilization
def calculate_usage(maybe_metrics) do
  fold_l(
    maybe_metrics,
    fn metrics ->
      %{
        total: Enum.sum(metrics),
        average: Enum.sum(metrics) / length(metrics),
        peak: Enum.max(metrics)
      }
    end,
    fn -> %{total: 0, average: 0.0, peak: 0} end
  )
end
```

## Protocol Implementations

Foldable uses **protocol-based polymorphism** - same interface, different runtime behavior:

### Branching Structures (Conditional Logic)

**Maybe Types**:
- `Just`: Calls `present_func` with wrapped value
- `Nothing`: Calls `absent_func` with no arguments

**Either Types**:
- `Right`: Calls `present_func` with success value  
- `Left`: Calls `absent_func` (ignores error details)

**Predicates (Functions)**:
- Evaluates predicate function
- Calls `present_func` if true, `absent_func` if false

### Ordered Collections (Traversal Logic)

**Lists**:
- Non-empty: Calls `present_func` with entire list
- Empty: Calls `absent_func`
- Uses Erlang's `:lists.foldl/3` and `:lists.foldr/3` internally

**Ranges**:
- Non-empty: Calls `present_func` with range
- Empty: Calls `absent_func`  
- Direction affects traversal order

## Integration with Other Protocols

### Fold + Monad (Pipeline Exit)

```elixir
import Funx.Foldable  
import Funx.Monad

# Monadic pipeline with fold extraction
def user_dashboard_workflow(user_id) do
  user_id
  |> fetch_user()                    # Maybe User
  |> bind(&validate_user/1)          # Maybe ValidUser  
  |> map(&build_dashboard/1)         # Maybe Dashboard
  |> fold_l(
      fn dashboard -> {:ok, dashboard} end,
      fn -> {:error, :user_not_found} end
    )
end
```

### Fold + Filter (Conditional Aggregation)

```elixir
import Funx.Foldable
import Funx.Filterable

# Filter then aggregate
def process_valid_data(maybe_users) do
  maybe_users
  |> filter(fn users -> length(users) > 0 end)    # Keep non-empty
  |> fold_l(fn users -> analyze_users(users) end, fn -> default_analysis() end)
end
```

## Performance Considerations

### Lazy Evaluation Benefits

```elixir
# Expensive computations only execute when needed
fold_l(
  maybe_data,
  fn data -> expensive_processing(data) end,    # Only runs if present
  fn -> expensive_default() end                 # Only runs if absent
)
```

### Short-Circuiting for Empty Structures

```elixir
# Early return for empty cases
fold_l(
  empty_list,
  fn _ -> complex_calculation() end,    # Never executes
  fn -> 0 end                          # Returns immediately
)
```

### Memory Efficiency

- **No intermediate collections** created during folding
- **Direct value transformation** without temporary structures
- **Tail recursion optimization** for large list folds

## Troubleshooting Common Issues

### Issue: Missing Absent Function

```elixir
# ❌ Problem: Only considering present case
fold_l(maybe_user, fn user -> user.name end)  # Compiler error!

# ✅ Solution: Always provide both functions  
fold_l(maybe_user, fn user -> user.name end, fn -> "Unknown" end)
```

### Issue: Wrong Function Arity

```elixir
# ❌ Problem: absent_func expecting parameters
fold_l(maybe_value, fn x -> x * 2 end, fn default -> default end)  # Wrong!

# ✅ Solution: absent_func takes no arguments
fold_l(maybe_value, fn x -> x * 2 end, fn -> default_value end)
```

### Issue: Confusing Fold Direction

```elixir
# ❌ Problem: Thinking direction matters for Maybe/Either
fold_r(maybe_value, present_func, absent_func)  # Same as fold_l!

# ✅ Understanding: Direction only matters for ordered collections
fold_l(maybe_value, present_func, absent_func)  # Standard choice
fold_r([1,2,3], combine_func, default_func)     # Direction affects traversal
```

### Issue: Using Fold Instead of Map/Bind

```elixir
# ❌ Problem: Using fold when you want to stay in context
fold_l(maybe_user, fn user -> Maybe.just(user.name) end, fn -> Maybe.nothing() end)

# ✅ Solution: Use map to transform within context
map(maybe_user, fn user -> user.name end)  # Stays in Maybe context
```

## When NOT to Use Foldable

### Use Convenience Functions for Simple Default Values

```elixir
# ❌ Manual fold for simple default values
fold_l(maybe_user, &Function.identity/1, fn -> "Anonymous" end)
fold_l(either_result, &Function.identity/1, fn -> "Error" end)

# ✅ Use convenience functions
Maybe.get_or_else(maybe_user, "Anonymous")
Either.get_or_else(either_result, "Error")
```

### Use Map When Staying in Context

```elixir
# ❌ Fold to transform while keeping structure
fold_l(maybe_user, fn user -> Maybe.just(transform(user)) end, fn -> Maybe.nothing() end)

# ✅ Map to transform while preserving context
map(maybe_user, &transform/1)  # Result is still Maybe
```

### Use Bind for Monadic Chaining

```elixir
# ❌ Fold for operations returning wrapped values
fold_l(maybe_user, fn user -> fetch_profile(user) end, fn -> Maybe.nothing() end)

# ✅ Bind for monadic sequencing
bind(maybe_user, &fetch_profile/1)  # Flattens nested Maybe
```

### Use Filter for Conditional Retention

```elixir
# ❌ Fold for conditional value retention
fold_l(maybe_value, fn x -> if x > 0, do: Maybe.just(x), else: Maybe.nothing() end, ...)

# ✅ Filter for conditional retention within context
filter(maybe_value, fn x -> x > 0 end)
```

## Best Practices

### 1. Fold as Universal Recursion Eliminator

Prefer fold over explicit pattern matching for composability:

```elixir
# ❌ Imperative: Scattered case statements
case result do
  %Either.Right{right: value} -> process(value)
  %Either.Left{} -> default
end

# ✅ Functional: Consistent fold interface  
fold_l(result, &process/1, fn -> default end)

# ❌ Imperative: Manual reduce with conditionals
case numbers do
  [] -> 0
  nums -> Enum.reduce(nums, 0, &+/2)
end

# ✅ Functional: Fold handles empty case automatically
fold_l(numbers, &Enum.sum/1, fn -> 0 end)
```

### 2. Stay in Context, Fold at Boundaries

Keep computations in monadic context as long as possible:

```elixir
# Do all transformations in wrapped context
result = 
  input
  |> Maybe.pure()
  |> map(&transform1/1)
  |> bind(&transform2/1)
  |> map(&transform3/1)
  # Stay in Maybe context ↑
  |> fold_l(&finalize/1, fn -> default_result end)  # Exit to concrete value ↓
```

### 3. Fold + Monoid for Powerful Aggregation

Combine folding with monoid operations:

```elixir
# Aggregate with monoid combination
scores
|> Enum.map(&calculate_score/1)           # Transform to scores
|> fold_l(&Enum.sum/1, fn -> 0 end)       # Aggregate with + monoid
```

### 4. Type-Driven Folding

Let types guide fold usage:
- **Have wrapped value, need concrete result** → Use fold
- **Have collection, need summary** → Use fold  
- **Have computation that might fail, need final result** → Use fold

## Summary

Foldable provides **polymorphic folding** - the universal pattern for collapsing structures into single values:

**Core Operations:**

- `fold_l/3`: Universal fold operation (standard choice)
- `fold_r/3`: Right-associative fold (for ordered collections needing specific direction)

**Two Folding Categories:**

- **Branching structures** (Maybe, Either, predicates): Context reconciliation through conditional logic
- **Ordered collections** (List, Range): Aggregation/reduction using Erlang's fold functions

**Key Patterns:**

- **Pipeline exit**: Extract concrete values from monadic contexts
- **Default provision**: Handle empty/missing cases with fallbacks
- **Tagged tuple reconciliation**: Convert success/error tuples to single results  
- **Collection aggregation**: Safely collapse collections with default handling

**Universal Insight:**

Folding is everywhere in programming - pattern matching, conditionals, reductions are all forms of folding. The `Foldable` protocol makes this pattern **explicit, composable, and polymorphic**.

**Functional Programming Philosophy:**

In Funx, **prefer fold over imperative conditionals and manual reduce operations**. Fold provides:
- **Unified interface** across all data types
- **Composable operations** that work in pipelines  
- **Explicit handling** of both success and failure cases
- **Type safety** through protocol dispatch

**Mental Model**: "I have a structure that might be empty, I need a concrete value, here's logic for both cases."

Remember: **Manage context-specific control logic within the pipeline, then fold to extract at the end.**