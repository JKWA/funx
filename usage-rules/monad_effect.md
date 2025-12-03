# `Funx.Monad.Effect` Usage Rules

## Quick Navigation Index

- **Construction**: `right/2`, `left/2`, `lift_func/2`, `lift_either/2`, `lift_maybe/3`
- **Composition**: `map/2`, `bind/2`, `ap/2`, `traverse/2`, `traverse_a/2`
- **Execution**: `run/1`, `run/2`, `Context`, `Task.Supervisor` integration
- **Validation**: `validate/2`, error accumulation patterns
- **Observability**: `span_name`, telemetry events, trace hierarchies

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- **Use `import Funx.Monad`** for access to `map/2`, `bind/2`, `ap/2` - protocol-based, not macros
- **Avoid `use Funx.Monad`** - Effect composition works via protocol dispatch, not macro injection
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Effect**: A deferred computation description that may succeed (`Right`) or fail (`Left`)

- **Pure descriptions**: Effects are pure instructions, not computations - execution is deferred
- **Concurrent by default**: Unlike ZIO, Effect runs concurrently - challenge is sequential control  
- **Controlled execution boundary**: `run/2` provides timeouts, isolation, and telemetry
- **Reader integration**: Built-in environment access for dependency injection
- **Exception-safe**: Automatically wraps exceptions in structured `EffectError`

**Theoretical Foundation**: Based on Philip Wadler's 1995 solution to the I/O problem

- **The Problem**: Side effects break referential transparency in functional programming
- **Wadler's Solution**: Model effects as pure instructions, defer execution to controlled boundary
- **Key Insight**: Instructions for producing side effects can remain pure even when effects themselves are impure
- **Effect Implementation**: Pure descriptions of computations + controlled execution in `run/2`
- **Preserves FP**: Maintains composability and reasoning while enabling real-world I/O

**Elixir-Specific Design**: Unlike most Effect libraries, Funx.Effect has **two distinct structs**

- **`Effect.Right`**: Describes a computation intended to succeed
- **`Effect.Left`**: Describes a computation intended to fail  
- **Pattern matching friendly**: Can match on Effect structure before execution
- **Structural short-circuiting**: `Effect.Left` detected during traversal—no task scheduled if Left matched early
- **Implementation quirk**: Makes functional composition cleaner in Elixir's pattern-matching environment

**Kleisli Function**: A function `a -> Effect b` (takes unwrapped value, returns wrapped Effect)

- **Primary use**: `traverse/2` and `traverse_a/2` for list operations  
- **Individual use**: `Monad.bind/2` for single Effect values
- **Context-aware**: Propagates trace context through execution
- Example: `fetch_user :: UserId -> Effect User`

**Key List Operation Patterns:**

- `sequence([Effect a])` → `Effect [a]` (fail-fast, sequential execution)
- `sequence_a([Effect a])` → `Effect [a]` (parallel execution, collect all errors)
- `traverse([a], kleisli_fn)` → `Effect [b]` (sequential: apply Kleisli, fail-fast)
- `traverse_a([a], kleisli_fn)` → `Effect [b]` (parallel: apply Kleisli, accumulate errors)

**Performance Critical**: `bind` chains run sequentially, `traverse_a` runs in parallel

**Functor**: Something you can `map` over while preserving structure

- `Monad.map/2 :: (a -> b) -> Effect a -> Effect b`
- Transforms the success value, leaves Left unchanged, preserves async structure

**Applicative**: Allows applying functions inside a context

- `Monad.ap/2 :: Effect (a -> b) -> Effect a -> Effect b`  
- Can combine multiple Effect values with proper trace context merging

**Monad**: Supports `bind` for chaining dependent computations

- `Monad.bind/2 :: Effect a -> (a -> Effect b) -> Effect b`
- Flattens nested Effect values automatically, maintains trace lineage

**Reader Pattern**: Access to runtime environment within effects

- `ask/0` - Returns environment as Right
- `asks/1` - Applies function to environment, returns result as Right
- `fail/0` - Returns environment as Left (failure mode)
- `fails/1` - Applies function to environment, returns result as Left

**Dependency Injection**: Inject behavior, not configuration

- Environment provides implementations: `%{store: MyStore, logger: MyLogger}`
- Effects remain decoupled from specific implementations
- Enables evolutionary design - defer architectural decisions safely

**Monad Relationships**: Effect combines familiar monadic patterns

- **Effect ≈ Reader + Either + Async**: Reads environment, produces Either results, defers execution
- **Reader integration**: `ask/0`, `asks/1`, `fail/0`, `fails/1` for environment access
- **Either foundation**: Operations return `Either.Right`/`Either.Left` when executed  
- **Async deferred**: Unlike Reader/Either, execution is deferred until `run/2`
- **Mathematical**: `Effect env a ≈ env -> Task (Either error a)` (execution semantics only)
- **Key difference**: Unlike `Task`, Effect descriptions are inert until `run/2`—nothing scheduled until execution

**Context & Observability**:

- Every Effect carries `Effect.Context` with trace_id, span_name, timeout
- Automatic telemetry emission on `run/2` with `[:funx, :effect, :run, :start/:stop]`
- Spans are linked hierarchically through parent_trace_id
- Exception handling wraps all errors in structured `EffectError`

## LLM Decision Guide: When to Use Effect

**✅ Use Effect when:**

- Deferred asynchronous computation (database calls, HTTP requests, file I/O)
- Need full observability and tracing in concurrent systems  
- Complex workflows requiring both fail-fast and error accumulation
- Integration with Task.Supervisor for fault tolerance
- Reader-style dependency injection with environment access
- User says: "async", "concurrent", "observable", "traced", "supervised"

**❌ Use Either when:**

- Synchronous operations that don't need deferral
- Simple error handling without telemetry overhead
- No need for tracing or span management
- User says: "simple validation", "immediate result", "no async"

**❌ Use Maybe when:**

- Simple presence/absence without error context
- No async requirements
- User says: "optional", "might not exist"

**⚡ Effect Strategy Decision:**

- **Simple async operation**: Use `right/1` and `left/1` constructors
- **Chain dependent async operations**: Use `bind/2` for Effect sequencing
- **Transform success values**: Use `map/2` with regular functions  
- **Combine multiple Effects**: Use `ap/2` for applicative patterns
- **Environment access**: Use `ask/0`, `asks/1`, `fail/0`, `fails/1`
- **List processing (fail-fast)**: Use `traverse/2` and `sequence/1`
- **List processing (parallel, accumulate errors)**: Use `traverse_a/2` and `sequence_a/1`
- **Validation with error accumulation**: Use `validate/2`
- **Performance optimization**: `bind` cheap checks before expensive ones
- **Exception-safe lifting**: Use `lift_func/2`, `lift_either/2`, etc.

**⚙️ Function Choice Guide (Mathematical Purpose):**

- **Chain dependent async lookups**: `bind/2` with functions returning Effect
- **Transform success values**: `map/2` with functions returning plain values
- **Apply functions to multiple Effects**: `ap/2` for combining contexts
- **Access runtime environment**: `ask/0` for full env, `asks/1` with selector
- **Fail with environment context**: `fail/0` or `fails/1`
- **Work with lists (fail-fast)**: `sequence/1`, `traverse/2`
- **Work with lists (collect errors)**: `sequence_a/1`, `traverse_a/2`
- **Lift synchronous operations**: `lift_func/2`, `lift_predicate/3`
- **Convert from other types**: `lift_either/2`, `lift_maybe/3`

## LLM Context Mapping

**User Intent → Effect Patterns:**

- "fetch user then profile" → `bind/2` chaining dependent operations
- "combine multiple API calls" → `traverse_a/2` for parallel processing  
- "validate with all errors" → `validate/2` with multiple validators
- "trace this operation" → Add `span_name` to context
- "handle database errors" → `map_left/2` for error transformation
- "access config in effect" → `asks/1` to read from environment
- "process list async" → `traverse_a/2` for error accumulation
- "async database call" → `lift_func/2` wrapping database operation
- "supervised task execution" → Pass `:task_supervisor` to `run/2`

## Syntax Patterns

- **Construction**: `Effect.right(value)`, `Effect.left(error)`
- **Composition**: `import Funx.Monad` then `|> bind(fn x -> ... end)`
- **Execution**: **Always call `run/2`** - Effects are lazy until executed
- **Environment**: `asks/1` for dependency injection, `run/2` provides environment
- **Error handling**: All exceptions wrapped in `EffectError`, use `map_left/2` for transformation
- **Tracing**: `span_name` creates hierarchical spans, context bound at creation

## Overview

`Funx.Monad.Effect` handles deferred asynchronous computations with full observability.

Use Effect for:

- Asynchronous operations (database, HTTP, file I/O)
- Complex workflows requiring tracing and telemetry  
- Error accumulation across multiple async operations
- Reader-style dependency injection with environment access
- Integration with Task.Supervisor for fault tolerance

**Key insight**: Effect represents **"deferred observable async computation"** - build up a pure description of what to do, then `run/2` executes it with full observability and exception safety.

**Remember**: Effects are pure until executed - this preserves functional programming benefits while enabling real-world I/O.

## Constructors

### `right/2` - Describe a Computation Intended to Succeed

Creates an `Effect.Right` struct describing a computation that should succeed:

```elixir
Effect.right(42)                    # Creates %Effect.Right{} - success intent
Effect.right(42, span_name: "calc") # With tracing context
```

### `left/2` - Describe a Computation Intended to Fail  

Creates an `Effect.Left` struct describing a computation that should fail:

```elixir
Effect.left("error")                      # Creates %Effect.Left{} - failure intent
Effect.left("error", span_name: "fail")  # With tracing context
```

**Key insight**: These create **different struct types** (`Effect.Right` vs `Effect.Left`), not the same struct with different content. This enables pattern matching on Effect structure before execution.

### `pure/2` - Alias for `right/2`

Alternative constructor for successful effects (Applicative identity):

```elixir
Effect.pure(42)                     # Same as Effect.right(42) - creates Effect.Right
Effect.pure(42, trace_id: "xyz")   # With custom trace context
```

**Note**: `pure/2` does not change concurrency or evaluation semantics—it creates an `Effect.Right` struct. Use in applicative patterns where you need the identity element for composition.

## Execution

### `run/1` - Execute the Effect

Executes the deferred computation and returns an Either result:

```elixir
import Funx.Monad

Effect.right(42)
|> Effect.run()                     # %Either.Right{right: 42}

Effect.left("error")  
|> Effect.run()                     # %Either.Left{left: "error"}
```

### `run/2` - Execute with Environment

Passes runtime environment to the effect:

```elixir
Effect.asks(fn env -> env[:user_id] end)
|> Effect.run(%{user_id: 123})     # %Either.Right{right: 123}
```

### `run/3` - Execute with Environment and Options

Supports additional execution options:

```elixir
{:ok, supervisor} = Task.Supervisor.start_link()

Effect.right(42)
|> Effect.run(%{}, task_supervisor: supervisor, span_name: "supervised")
```

## Core Operations

### `map/2` - Transform Success Values

Applies a function to the success value inside an Effect:

```elixir
import Funx.Monad

Effect.right(5)
|> map(fn x -> x * 2 end)
|> Effect.run()                     # right(10)

Effect.left("error")
|> map(fn x -> x * 2 end)
|> Effect.run()                     # left("error") - function never runs
```

**Use `map` when:**

- You want to transform the success value if present
- The transformation function returns a plain value (not wrapped in Effect)
- You want to preserve the Effect structure and async nature

### `bind/2` - Chain Dependent Async Operations

Chains operations that return Effect values, automatically flattening:

```elixir
import Funx.Monad

# These functions return Effect values  
fetch_user = fn id -> 
  Effect.lift_func(fn -> Database.get_user(id) end) 
end

fetch_profile = fn user -> 
  Effect.lift_func(fn -> Database.get_profile(user.id) end)
end

Effect.right(123)
|> bind(fetch_user)           # Effect User
|> bind(fetch_profile)        # Effect Profile  
|> Effect.run(env)
```

**Use `bind` when:**

- You're chaining async operations that each return Effect
- Each step depends on the result of the previous async step
- You want automatic short-circuiting on Left with trace preservation
- You need sequential execution (each operation waits for the previous)

**Common bind pattern (sequential execution):**

```elixir
def process_user_workflow(user_id, env) do
  Effect.right(user_id)
  |> bind(&fetch_user_async/1)       # UserId -> Effect User
  |> bind(&fetch_permissions_async/1) # User -> Effect Permissions
  |> bind(&validate_access_async/1)   # Permissions -> Effect AccessToken
  |> Effect.run(env)
end
```

### `ap/2` - Apply Functions Across Effect Values

Applies a function in an Effect to a value in an Effect:

```elixir
import Funx.Monad

# Apply a wrapped function to wrapped values
Effect.right(fn x -> x + 10 end)
|> ap(Effect.right(5))
|> Effect.run()                     # right(15)

# Combine multiple Effect values  
add = fn x -> fn y -> x + y end end

Effect.right(add)
|> ap(Effect.right(3))              # Effect(fn y -> 3 + y end)
|> ap(Effect.right(4))              # Effect(7)
|> Effect.run()                     # right(7)

# If any value is Left, result is Left
Effect.right(add)
|> ap(Effect.left("error"))         
|> ap(Effect.right(4))
|> Effect.run()                     # left("error")
```

**Use `ap` when:**

- You want to apply a function to multiple Effect values
- You need all async operations to complete for the computation to succeed
- You're implementing applicative patterns with trace context preservation

**Concurrency note**: `ap/2` enables applicative composition. Provided both arguments are constructed independently, effects may run concurrently. However, if Effects are constructed in dependency chains, they will run sequentially.

### `tap/2` - Side Effects Without Changing Values

Executes a side-effect function on a Right value and returns the original Effect unchanged. If the Effect is Left, the function is not called. The side effect is **deferred** - it executes when the Effect is run, not when `tap` is called:

```elixir
import Funx.Monad.Effect

# Side effect on Right (deferred until run)
Effect.right(42)
|> Effect.tap(fn x -> Logger.info("Value: #{x}") end)
|> Effect.run()  # Logs "Value: 42", returns right(42)

# No side effect on Left
Effect.left("error")
|> Effect.tap(fn x -> Logger.info("Value: #{x}") end)
|> Effect.run()  # Nothing logged, returns left("error")
```

**Use `tap` when:**

- Debugging async pipelines - inspect values without breaking the chain
- Logging async operations - record intermediate results
- Telemetry for async workflows - emit events at specific points
- Side effects in async code - perform actions without changing the computation

**Common tap patterns:**

```elixir
# Debug async pipeline
fetch_user(user_id)
|> Effect.tap(&IO.inspect(&1, label: "fetched user"))
|> bind(&fetch_orders/1)
|> Effect.tap(&IO.inspect(&1, label: "fetched orders"))
|> Effect.run(env)

# Logging in async workflow
process_payment(order)
|> Effect.tap(fn result -> Logger.info("Payment processed: #{result.id}") end)
|> bind(&send_confirmation/1)
|> Effect.tap(fn _ -> Logger.info("Confirmation sent") end)
|> Effect.run(env)

# Telemetry for async operations
calculate_analytics(data)
|> Effect.tap(fn metrics ->
  :telemetry.execute([:app, :analytics], metrics)
end)
|> Effect.run(env)
```

**Important notes:**

- The function's return value is discarded
- **Deferred execution**: side effect runs when Effect.run() is called
- Only executes on Right values (success path)
- Properly promotes trace context for telemetry tracking
- Side effects execute inside async Task (may need to handle process communication carefully)

## Reader Operations

### `ask/0` - Access Full Environment

Returns the runtime environment passed to `run/2` as a Right:

```elixir
Effect.ask()
|> map(fn env -> env[:database_url] end)
|> Effect.run(%{database_url: "postgres://..."})  # right("postgres://...")
```

### `asks/1` - Extract from Environment  

Applies a function to extract specific values from the environment:

```elixir
Effect.asks(fn env -> env[:config][:timeout] end)
|> Effect.run(%{config: %{timeout: 5000}})        # right(5000)
```

### `fail/0` - Fail with Full Environment

Returns the runtime environment as a Left (failure case):

```elixir
Effect.fail()
|> Effect.run(%{error: :invalid_token})           # left(%{error: :invalid_token})
```

### `fails/1` - Fail with Processed Environment

Applies a function to the environment and returns result as Left:

```elixir
Effect.fails(fn env -> {:unauthorized, env[:user_id]} end)
|> Effect.run(%{user_id: 42})                     # left({:unauthorized, 42})
```

**Reader Pattern Usage:**

```elixir
def fetch_with_config do
  Effect.asks(fn env -> {env[:api_base], env[:auth_token]} end)
  |> bind(fn {base, token} ->
    Effect.lift_func(fn -> HTTPClient.get("#{base}/users", headers: [{"auth", token}]) end)
  end)
end
```

**Understanding the Monad Stack:**

```elixir
# Effect combines three familiar patterns:

# 1. Reader: Environment access
Effect.asks(fn env -> env[:database_config] end)

# 2. Either: Success/failure handling  
|> bind(fn config ->
  case Database.connect(config) do
    {:ok, conn} -> Effect.right(conn)      # Success path
    {:error, reason} -> Effect.left(reason) # Failure path
  end
end)

# 3. Async: Deferred execution until run/2
|> Effect.run(%{database_config: config})  # Returns Either.Right or Either.Left

# Mathematically: Effect env a ≈ env -> Task (Either error a)
```

## Context & Observability

### Effect.Context - Tracing and Telemetry

Every Effect carries context for observability:

```elixir
# Create context with span name and timeout
context = Effect.Context.new(
  span_name: "fetch_user_data",
  timeout: 10_000,
  trace_id: "custom-trace-id"
)

Effect.right(user_id, context)
|> bind(&fetch_user_async/1)
|> Effect.run(env)

# Telemetry events emitted:
# [:funx, :effect, :run, :start] - when execution begins  
# [:funx, :effect, :run, :stop]  - when execution completes
```

### Span Naming and Hierarchies

Effects automatically create hierarchical spans:

```elixir
# Parent effect
parent_effect = Effect.right(42, span_name: "parent_operation")

# Child operations create nested spans
result = parent_effect
|> bind(fn x -> 
  Effect.right(x * 2, span_name: "double_value")  # Creates "bind -> parent_operation"
end)
|> map(fn x -> x + 1)  # Creates "map -> bind -> parent_operation"
|> Effect.run(env, span_name: "execute")  # Promotes to "execute -> map -> bind -> parent_operation"
```

### Telemetry Events

Effect automatically emits structured telemetry events for observability:

**Core Events:**

```elixir
# When Effect execution begins
[:funx, :effect, :run, :start]

# When Effect execution completes
[:funx, :effect, :run, :stop]
```

**Event Metadata:**

```elixir
%{
  span_name: "user_operation",        # Current span name
  trace_id: "abc123...",             # Unique trace identifier  
  parent_trace_id: "def456...",      # Parent span if nested
  timeout: 5000,                     # Configured timeout
  # Plus any custom metadata from Context
}
```

**Measurements:**

```elixir
%{
  duration: 1_234_567,  # Execution time in nanoseconds (for :stop events)
  count: 1              # Always 1 for Effect executions
}
```

**Example telemetry handler:**

```elixir
:telemetry.attach_many(
  "effect-observer",
  [[:funx, :effect, :run, :start], [:funx, :effect, :run, :stop]],
  fn event, measurements, metadata, _config ->
    case event do
      [:funx, :effect, :run, :start] ->
        Logger.info("Effect started: #{metadata.span_name}")
        
      [:funx, :effect, :run, :stop] ->
        duration_ms = measurements.duration / 1_000_000
        Logger.info("Effect completed: #{metadata.span_name} in #{duration_ms}ms")
    end
  end,
  nil
)
```

### Exception Handling

All exceptions are automatically wrapped in `EffectError`:

```elixir
Effect.lift_func(fn -> 1 / 0 end)  
|> Effect.run()
# Returns: left(%EffectError{stage: :lift_func, reason: %ArithmeticError{}})

Effect.right(42)
|> map(fn _ -> raise "boom" end)
|> Effect.run()  
# Returns: left(%EffectError{stage: :map, reason: %RuntimeError{message: "boom"}})
```

**EffectError Structure:**

```elixir
%Funx.Errors.EffectError{
  stage: atom(),    # Where error occurred: :lift_func, :map, :bind, :ap, :run
  reason: any()     # Original exception or error reason
}
```

**Common EffectError stages:**

- `:lift_func` - Exception in lifted function
- `:map` - Exception in map transformation  
- `:bind` - Exception in bind function
- `:ap` - Exception in applicative function
- `:run` - Timeout or task execution failure
- `:lift_either` - Exception in Either-returning function

## List Operations

### `sequence/1` - Fail-Fast Processing

Processes a list of Effects, stopping at the first Left:

```elixir
effects = [
  Effect.right(1, span_name: "first"),
  Effect.right(2, span_name: "second"), 
  Effect.right(3, span_name: "third")
]

Effect.sequence(effects)
|> Effect.run()                     # right([1, 2, 3])

# With failure - stops at first Left (pattern matching optimization)
effects_with_error = [
  Effect.right(1),
  Effect.left("error"),    # %Effect.Left{} - can short-circuit here
  Effect.right(3)          # Never executes because Left found
]

Effect.sequence(effects_with_error)
|> Effect.run()                     # left("error")
```

**Elixir-specific optimization**: Because `Effect.left/2` creates an `%Effect.Left{}` struct, traversals can pattern match for structural short-circuiting—no task is scheduled if a Left is detected early during traversal construction.

### `sequence_a/1` - Error Accumulation

Processes all Effects and accumulates any errors:

```elixir
effects_with_errors = [
  Effect.right(1),
  Effect.left("Error 1"),
  Effect.left("Error 2"), 
  Effect.right(4)
]

Effect.sequence_a(effects_with_errors)
|> Effect.run()                     # left(["Error 1", "Error 2"])

# All succeed
all_success = [Effect.right(1), Effect.right(2), Effect.right(3)]

Effect.sequence_a(all_success)
|> Effect.run()                     # right([1, 2, 3])
```

### `traverse/2` - Apply Kleisli Function (Fail-Fast)

Applies a Kleisli function to each element, stopping at first failure:

```elixir
validate_positive = fn n ->
  Effect.lift_predicate(n, &(&1 > 0), fn x -> "#{x} is not positive" end)
end

Effect.traverse([1, 2, 3], validate_positive)
|> Effect.run()                     # right([1, 2, 3])

Effect.traverse([1, -2, 3], validate_positive)  
|> Effect.run()                     # left("-2 is not positive")
```

### `traverse_a/2` - Apply Kleisli Function (Accumulate Errors)

Applies a Kleisli function to each element, collecting all errors:

```elixir
Effect.traverse_a([1, -2, -3], validate_positive)
|> Effect.run()                     # left(["-2 is not positive", "-3 is not positive"])
```

**Use `traverse` vs `traverse_a`:**

- **traverse**: When you need all operations to succeed (fail-fast, sequential)
- **traverse_a**: When you want to see all validation errors (accumulate, parallel)

**Key Performance Difference**: `traverse_a` runs all operations concurrently, `traverse` stops at first failure.

### `validate/2` - Multi-Validator Error Accumulation  

Validates a value using multiple validator functions:

```elixir
validate_positive = fn x ->
  Effect.lift_predicate(x, &(&1 > 0), fn n -> "#{n} must be positive" end)
end

validate_even = fn x ->
  Effect.lift_predicate(x, &(rem(&1, 2) == 0), fn n -> "#{n} must be even" end)
end

# All validators pass
Effect.validate(4, [validate_positive, validate_even])
|> Effect.run()                     # right(4)

# Multiple validators fail - accumulates errors
Effect.validate(-3, [validate_positive, validate_even])  
|> Effect.run()                     # left(["-3 must be positive", "-3 must be even"])
```

## Lifting Operations

### `lift_func/2` - Lift Synchronous Function

Lifts a zero-arity function into an Effect, executing it asynchronously:

```elixir
Effect.lift_func(fn -> expensive_computation() end)
|> Effect.run()                     # Runs async, returns right(result)

# Exception handling
Effect.lift_func(fn -> raise "boom" end)
|> Effect.run()                     # left(%EffectError{stage: :lift_func, reason: %RuntimeError{}})
```

### `lift_either/2` - Lift Either-Returning Function

Lifts a function that returns Either into an Effect:

```elixir
Effect.lift_either(fn -> validate_email("user@example.com") end)
|> Effect.run()                     # Defers Either evaluation until run
```

### `lift_maybe/3` - Lift Maybe with Fallback

Converts a Maybe into an Effect with error fallback:

```elixir
maybe_user = Maybe.just(%User{id: 1})

Effect.lift_maybe(maybe_user, fn -> "User not found" end)
|> Effect.run()                     # right(%User{id: 1})

Effect.lift_maybe(Maybe.nothing(), fn -> "User not found" end)  
|> Effect.run()                     # left("User not found")
```

### `lift_predicate/3` - Lift Predicate Check

Lifts a predicate validation into an Effect:

```elixir
Effect.lift_predicate(10, &(&1 > 5), fn x -> "#{x} too small" end)
|> Effect.run()                     # right(10)

Effect.lift_predicate(3, &(&1 > 5), fn x -> "#{x} too small" end)
|> Effect.run()                     # left("3 too small")
```

## Error Handling

### `map_left/2` - Transform Left Values

Transforms error values while leaving Right unchanged:

```elixir
Effect.left("simple error")
|> Effect.map_left(fn e -> %{error: e, code: 400} end)
|> Effect.run()                     # left(%{error: "simple error", code: 400})

Effect.right(42)
|> Effect.map_left(fn _ -> "never called" end)
|> Effect.run()                     # right(42)
```

### `flip_either/1` - Invert Success/Failure

Swaps Right and Left values:

```elixir
Effect.flip_either(Effect.right("success"))
|> Effect.run()                     # left("success")

Effect.flip_either(Effect.left("error"))  
|> Effect.run()                     # right("error")
```

## Common Patterns

### Async Pipeline with Error Handling

```elixir
def process_user_registration(email, password, env) do
  Effect.right({email, password})
  |> bind(fn {e, p} -> validate_email_async(e) |> map(fn _ -> {e, p} end) end)
  |> bind(fn {e, p} -> hash_password_async(p) |> map(fn h -> {e, h} end) end)
  |> bind(fn {e, h} -> create_user_async(e, h) end)
  |> bind(&send_welcome_email_async/1)
  |> Effect.run(env)
end
```

### Parallel API Calls with Error Accumulation

```elixir  
def fetch_dashboard_data(user_id, env) do
  api_calls = [
    fetch_user_profile(user_id),
    fetch_recent_orders(user_id),  
    fetch_recommendations(user_id)
  ]
  
  Effect.sequence_a(api_calls, span_name: "dashboard_data")
  |> map(fn [profile, orders, recs] -> 
    %{profile: profile, orders: orders, recommendations: recs}
  end)
  |> Effect.run(env)
end
```

### Performance-Optimized Validation Pipeline

```elixir
def validate_ride_access(patron, ride, env) do
  # Fast local checks first (milliseconds)
  Effect.right(patron)
  |> bind(&validate_age_height/1)
  |> bind(&validate_ticket_tier/1)
  |> bind(fn patron ->
    # Only do expensive I/O checks for eligible patrons (500ms)
    check_ride_maintenance_status(ride, env)
    |> map(fn _ -> patron end)
  end)
  |> Effect.run(env)
end

# bind chains: Sequential execution, short-circuit on first failure  
# traverse_a: Parallel execution, collect all errors
```

### Dependency Injection with Reader

```elixir
# Effect stays decoupled from specific implementations
def save_user_data(user, env) do
  Effect.asks(fn e -> {e[:store], e[:logger]} end)
  |> bind(fn {store, logger} ->
    Effect.lift_func(fn -> logger.info("Saving user #{user.id}") end)
    |> bind(fn _ -> store.save(user) end)
  end)  
  |> Effect.run(env)
end

# Runtime injection enables evolutionary design
dev_env = %{store: InMemoryStore, logger: ConsoleLogger}
prod_env = %{store: PostgreSQLStore, logger: TelemetryLogger}
```

### Timeout and Supervision

```elixir
{:ok, sup} = Task.Supervisor.start_link()

context = Effect.Context.new(
  span_name: "long_running_task",
  timeout: 30_000
)

Effect.lift_func(fn -> very_expensive_operation() end, context)
|> Effect.run(%{}, task_supervisor: sup)
```

## Elixir Interoperability

### `from_result/2` - Convert Result Tuples

```elixir
Effect.from_result({:ok, 42})
|> Effect.run()                     # right(42)

Effect.from_result({:error, "failed"})
|> Effect.run()                     # left("failed")
```

### `to_result/1` - Convert to Result Tuples

```elixir
Effect.to_result(Effect.right(42))              # {:ok, 42}
Effect.to_result(Effect.left("error"))          # {:error, "error"}
```

### `from_try/2` - Exception-Safe Kleisli

Creates a Kleisli function that catches exceptions:

```elixir
safe_div = Effect.from_try(fn x -> 10 / x end)

Effect.right(2)
|> bind(safe_div)
|> Effect.run()                     # right(5.0)

Effect.right(0)  
|> bind(safe_div)
|> Effect.run()                     # left(%ArithmeticError{})
```

### `to_try!/1` - Extract or Raise

```elixir
Effect.to_try!(Effect.right(42))                # 42

Effect.to_try!(Effect.left(%RuntimeError{message: "boom"}))  
# raises RuntimeError: "boom"
```

## Testing Strategies

### Property-Based Testing

```elixir
defmodule EffectPropertyTest do
  use ExUnit.Case
  use StreamData
  import Funx.Monad

  property "map preserves Right structure" do
    check all value <- term(),
              f <- StreamData.constant(fn x -> x + 1 end) do
      result = Effect.right(value) |> map(f) |> Effect.run()
      assert match?(%Either.Right{}, result)
    end
  end

  property "bind chains preserve trace context" do
    check all value <- integer() do
      effect = Effect.right(value, span_name: "test")
      |> bind(fn x -> Effect.right(x * 2, span_name: "double") end)
      
      result = Effect.run(effect)
      assert match?(%Either.Right{right: doubled}, result) when doubled == value * 2
    end
  end
end
```

### Unit Testing with Telemetry

```elixir
defmodule EffectTest do
  use ExUnit.Case
  import Funx.Monad

  setup do
    :telemetry.attach_many(
      "test-handler",
      [[:funx, :effect, :run, :start], [:funx, :effect, :run, :stop]],
      fn event, measurements, metadata, _ ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )
    
    on_exit(fn -> :telemetry.detach("test-handler") end)
  end

  test "async pipeline emits correct telemetry" do
    result = Effect.right(10, span_name: "start")
    |> bind(fn x -> Effect.right(x * 2, span_name: "double") end)
    |> Effect.run()

    assert result == Either.right(20)
    
    assert_received {:telemetry, [:funx, :effect, :run, :stop], _, %{span_name: "start"}}
    assert_received {:telemetry, [:funx, :effect, :run, :stop], _, %{span_name: "double"}}  
    assert_received {:telemetry, [:funx, :effect, :run, :stop], _, %{span_name: "bind -> start"}}
  end

  test "error accumulation in traverse_a" do
    validator = fn x ->
      if x > 0, do: Effect.right(x), else: Effect.left("negative: #{x}")
    end
    
    result = Effect.traverse_a([1, -2, 3, -4], validator) |> Effect.run()
    
    assert result == Either.left(["negative: -2", "negative: -4"])
  end
end
```

## Performance Considerations

### Sequential vs Parallel Execution Patterns

```elixir
# ❌ Sequential: 1.5 seconds total (3 × 500ms each)
def check_maintenance_sequential(ride) do
  Effect.right(ride)
  |> bind(&check_scheduled_maintenance/1)  # 500ms
  |> bind(&check_unscheduled_maintenance/1) # 500ms  
  |> bind(&check_compliance_hold/1)        # 500ms
  |> Effect.run()
end

# ✅ Parallel: 500ms total (all run concurrently)  
def check_maintenance_parallel(ride) do
  checks = [
    check_scheduled_maintenance(ride),     # 500ms concurrent
    check_unscheduled_maintenance(ride),   # 500ms concurrent
    check_compliance_hold(ride)            # 500ms concurrent
  ]
  
  Effect.sequence_a(checks) |> Effect.run()  # All run in parallel
end

# Rule: Use bind for dependent operations, traverse_a for independent operations
```

### Smart Performance Optimization

```elixir
# ✅ Fast eligibility checks before expensive I/O
def validate_access_optimized(patron, ride) do
  Effect.right(patron)
  # Fast local validations first (1-2ms total)
  |> bind(&validate_age/1)
  |> bind(&validate_height/1) 
  |> bind(&validate_ticket/1)
  # Only do expensive I/O for eligible patrons (500ms)
  |> bind(fn _ -> check_ride_online_status(ride) end)
end

# Best case: Ineligible patron rejected in 2ms
# Worst case: Eligible patron checked in 502ms
```

### Context Propagation Overhead

```elixir
# Context merging and span creation has minimal overhead
# But consider span naming strategy for high-volume operations

# Good: Generic span names for repeated operations
Effect.lift_func(fn -> process_item(item) end, span_name: "process_item")

# Avoid: Unique span names that create too many distinct spans  
# Effect.lift_func(fn -> process_item(item) end, span_name: "process_item_#{item.id}")
```

### Memory Usage

```elixir
# Effects are lightweight until executed
# Deferred nature means no computation until run/2

# Efficient for conditional execution
user_effect = if admin_user? do
  Effect.lift_func(fn -> expensive_admin_operation() end)
else
  Effect.right(:skip)
end

# Only runs expensive operation if needed
Effect.run(user_effect)
```

## Troubleshooting Common Issues

### Issue: Forgetting to Call `run/2`

```elixir
# ❌ Problem: Effect never executes
effect = Effect.right(42)
# Missing Effect.run(effect) - nothing happens!

# ✅ Solution: Always call run to execute
result = Effect.right(42) |> Effect.run()
```

### Issue: Nested Effect Values

```elixir
# ❌ Problem: Manual nesting creates Effect Effect a
result = Effect.right(user_id)
|> map(&fetch_user_effect/1)  # fetch_user_effect returns Effect User  
# Result: Effect (Effect User) - nested!

# ✅ Solution: Use bind for functions that return Effect
result = Effect.right(user_id)
|> bind(&fetch_user_effect/1)  # Automatically flattens to Effect User
```

### Issue: Blocking on Async Operations

```elixir
# ❌ Problem: Sequential execution loses concurrency benefits
def fetch_data_slow(ids) do
  Enum.reduce(ids, Effect.right([]), fn id, acc ->
    acc |> bind(fn results ->
      fetch_item(id) |> map(fn item -> [item | results] end)
    end)
  end)
end

# ✅ Solution: Use traverse_a for concurrent processing
def fetch_data_fast(ids) do
  Effect.traverse_a(ids, &fetch_item/1)
end
```

### Issue: Losing Error Context

```elixir
# ❌ Problem: Generic error handling loses specifics
Effect.lift_func(fn -> Database.query("SELECT * FROM users") end)
|> map_left(fn _ -> "database error" end)  # Lost original error details

# ✅ Solution: Preserve error context  
Effect.lift_func(fn -> Database.query("SELECT * FROM users") end)
|> map_left(fn 
  %EffectError{reason: %DBConnection.Error{} = db_err} -> 
    %{error: :database, details: db_err, operation: :fetch_users}
  error -> 
    %{error: :unknown, details: error, operation: :fetch_users}
end)
```

### Issue: Trace Context Confusion

```elixir
# ❌ Problem: Inconsistent span naming makes tracing hard to follow
Effect.right(data, span_name: "a") 
|> bind(fn x -> Effect.right(process(x), span_name: "x") end)
|> map(fn y -> transform(y))  # No span name context lost

# ✅ Solution: Consistent span naming strategy
Effect.right(data, span_name: "load_user_data")
|> bind(fn x -> Effect.right(process(x), span_name: "validate_user_data") end)  
|> map(fn y -> transform(y))  # Inherits "map -> validate_user_data"
```

## When Not to Use Effect

### Use Either Instead When

```elixir
# ❌ Effect overhead for simple sync validation
def validate_email_sync(email) do
  Effect.lift_predicate(email, &valid_email_format?/1, fn _ -> "invalid email" end)
  |> Effect.run()
end

# ✅ Either for immediate sync operations  
def validate_email_sync(email) do
  if valid_email_format?(email) do
    Either.right(email)
  else
    Either.left("invalid email")
  end
end
```

### Use OTP/GenServer Instead for Long-Running Tasks

```elixir
# ❌ Effect for persistent background workers
def start_queue_processor do
  Effect.lift_func(fn ->
    spawn(fn -> 
      # This runs forever - Effect is wrong abstraction
      continuously_process_queue()
    end)
  end)
  |> Effect.run()
end

# ✅ GenServer for stateful, long-running services
defmodule QueueProcessor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_work()
    {:ok, %{processed: 0}}
  end

  def handle_info(:work, state) do
    process_next_item()
    schedule_work()
    {:noreply, %{state | processed: state.processed + 1}}
  end

  defp schedule_work do
    Process.send_after(self(), :work, 1000)
  end
end
```

### Use Job Queues Instead for High-Volume Processing

```elixir
# ❌ Effect for job queues - no back-pressure or persistence
def process_user_sign_ups(user_ids) do
  Effect.traverse_a(user_ids, fn id ->
    Effect.lift_func(fn -> send_welcome_email(id) end)
  end)
  |> Effect.run()
end

# ✅ Oban for reliable job processing with back-pressure
defmodule WelcomeEmailWorker do
  use Oban.Worker, queue: :emails, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    send_welcome_email(user_id)
    :ok
  end
end

# Enqueue jobs with back-pressure and persistence
def process_user_sign_ups(user_ids) do
  jobs = Enum.map(user_ids, fn id ->
    WelcomeEmailWorker.new(%{user_id: id})
  end)
  
  Oban.insert_all(jobs)
end
```

### Use Streaming Libraries Instead for Data Pipelines

```elixir
# ❌ Effect for large data processing - memory issues
def process_large_dataset(data) do
  Effect.traverse_a(data, fn item ->
    Effect.lift_func(fn -> expensive_transformation(item) end)
  end)
  |> Effect.run()
end

# ✅ Flow for back-pressured stream processing
def process_large_dataset(data) do
  data
  |> Flow.from_enumerable(max_demand: 100)
  |> Flow.map(&expensive_transformation/1)
  |> Flow.partition()
  |> Flow.reduce(fn -> [] end, fn item, acc -> [item | acc] end)
  |> Enum.to_list()
end

# ✅ Broadway for robust event processing
defmodule DataProcessor do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayRabbitMQ.Producer, queue: "data_queue"}
      ],
      processors: [
        default: [concurrency: 10]
      ]
    )
  end

  def handle_message(_processor, message, _context) do
    message
    |> Message.update_data(&expensive_transformation/1)
  end
end
```

### But Effect Enables Evolutionary Design

```elixir
# Start simple - Effect allows architectural evolution
def check_user_status(user_id) do
  # Initially: simple boolean check
  Effect.right(user_id > 0)
  |> Effect.run()
end

# Later: evolve to database lookup without changing interface  
def check_user_status(user_id) do
  Effect.asks(fn env -> env[:user_store] end)
  |> bind(fn store -> store.get_user_status(user_id) end)
  |> Effect.run(env)
end

# Finally: evolve to complex validation with multiple services
def check_user_status(user_id) do
  status_checks = [
    check_account_standing(user_id),
    check_payment_status(user_id), 
    check_compliance_status(user_id)
  ]
  
  Effect.sequence_a(status_checks)
  |> map(&all_checks_passed?/1)
  |> Effect.run(env)
end
```

### Use Plain Values When

```elixir
# ❌ Effect for pure computations
def calculate_tax_async(amount) do
  Effect.lift_func(fn -> amount * 0.1 end)
  |> Effect.run()
end

# ✅ Plain computation for pure functions
def calculate_tax(amount) do
  amount * 0.1
end
```

### Effect's Sweet Spot: Basic Async I/O

```elixir
# ✅ Effect is perfect for basic async operations
def fetch_user_dashboard(user_id, env) do
  parallel_requests = [
    fetch_user_profile(user_id),      # HTTP request
    fetch_recent_orders(user_id),     # Database query
    fetch_notifications(user_id)      # Cache lookup
  ]
  
  Effect.sequence_a(parallel_requests)
  |> map(&build_dashboard_response/1)
  |> Effect.run(env)
end

# ✅ Effect handles composition of discrete async operations well
def process_payment(payment_data, env) do
  Effect.right(payment_data)
  |> bind(&validate_payment_info/1)     # Quick validation
  |> bind(&charge_payment_processor/1)  # External API call
  |> bind(&update_user_account/1)       # Database update
  |> bind(&send_receipt_email/1)        # Email service call
  |> Effect.run(env)
end
```

## Architecture Decision Guide

**Use Effect for:**

- ✅ **Basic async I/O**: Database calls, HTTP requests, file operations
- ✅ **Composed workflows**: 3-10 step async pipelines with error handling
- ✅ **Request/response patterns**: Web request processing, API calls
- ✅ **Short-lived tasks**: Operations completing in seconds to minutes
- ✅ **Functional composition**: When you need monadic error handling

**Use OTP (GenServer/Agent) for:**

- ✅ **Stateful services**: Caches, connection pools, rate limiters  
- ✅ **Long-running processes**: Background workers, schedulers, monitors
- ✅ **System resources**: Database connections, file handles, network sockets
- ✅ **Fault tolerance**: Supervised processes that can restart
- ✅ **Message passing**: Actor-based communication patterns

**Use Job Queues (Oban/Exq) for:**

- ✅ **Reliable processing**: Jobs that must complete eventually
- ✅ **Back-pressure**: High-volume work that needs rate limiting
- ✅ **Persistence**: Jobs that survive application restarts
- ✅ **Retry logic**: Complex retry strategies with exponential backoff
- ✅ **Scheduled work**: Cron-like scheduling, delayed execution

**Use Streaming (Flow/Broadway) for:**  

- ✅ **Large datasets**: Processing data that doesn't fit in memory
- ✅ **Continuous streams**: Real-time event processing
- ✅ **ETL pipelines**: Extract, transform, load operations
- ✅ **Back-pressured workflows**: Producer/consumer with flow control
- ✅ **Parallel processing**: CPU-intensive batch operations

**Rule of thumb:** If it runs for more than a few minutes, processes thousands of items, or needs to survive application restarts, Effect is probably the wrong tool.

## Summary

Effect provides pure descriptions of asynchronous computations with full observability:

**Core Philosophy:**

- **Pure descriptions**: Effects are instructions, not computations - execution is deferred
- **Concurrent by default**: Effects run in parallel unless explicitly sequenced  
- **Controlled execution**: `run/2` provides isolation, timeouts, and telemetry
- **Evolutionary design**: Start simple, evolve complexity without changing interfaces

**Core Operations:**

- `right/2`: Describe successful async computations
- `left/2`: Describe failed async computations  
- `run/2`: Execute the deferred Effect with environment and full observability
- `map/2`: Transform success values while preserving async structure
- `bind/2`: Chain dependent operations sequentially with trace propagation
- `traverse_a/2`: Process lists in parallel with error accumulation

**Key Performance Patterns:**

- **Sequential processing**: Use `bind/2` for dependent operations (slower but controlled)
- **Parallel processing**: Use `traverse_a/2` for independent operations (faster)
- **Performance optimization**: `bind` cheap local checks before expensive I/O
- **Dependency injection**: Use Reader pattern for evolutionary architecture

**Mathematical Properties:**

- **Functor**: `map` preserves structure and async context  
- **Applicative**: `traverse_a` enables parallel processing with error collection
- **Monad**: `bind` enables dependent sequencing with automatic flattening
- **Reader**: `asks/1` enables dependency injection and evolutionary design
- **Monad Transformer**: Effect ≈ ReaderT (EitherT (Task a)) - Reader over Either over Task
- **Transformer note**: In languages with higher-kinded types, this could use transformer layering. In Elixir, Effect encodes the combined stack explicitly.

## Law Reference for LLM Verification

LLMs can use these mathematical laws to verify correctness of Effect code:

| Law | Operation | Expression | Validity |
|-----|-----------|------------|----------|
| **Functor Identity** | `map/2` | `map(fn x -> x end, fx) == fx` | ✅ Always |
| **Functor Composition** | `map/2` | `map(g, map(f, fx)) == map(fn x -> g.(f.(x)) end, fx)` | ✅ Always |
| **Applicative Identity** | `ap/2` | `ap(pure(fn x -> x end), fx) == fx` | ✅ Always |
| **Applicative Composition** | `ap/2` | Complex composition law with `pure` | ✅ Always |
| **Applicative Homomorphism** | `ap/2` | `ap(pure(f), pure(x)) == pure(f.(x))` | ✅ Always |
| **Monad Left Identity** | `bind/2` | `bind(pure(x), f) == f.(x)` | ✅ Always |
| **Monad Right Identity** | `bind/2` | `bind(mx, &pure/1) == mx` | ✅ Always |
| **Monad Associativity** | `bind/2` | `bind(bind(mx, f), g) == bind(mx, fn x -> bind(f.(x), g) end)` | ✅ Always |
| **Reader Ask Law** | `asks/1` | `asks(fn env -> env end) == ask()` | ✅ Always |
| **Reader Local Law** | Environment | Laws about environment propagation | ✅ Always |

**LLM Verification Usage**: If user code violates these laws, it's likely incorrect Effect usage.

**Observability Features:**

- Automatic telemetry emission with structured events
- Hierarchical span creation preserving trace lineage  
- Exception safety with structured `EffectError` wrapping
- Context propagation enabling distributed tracing

## Final LLM Guidance

**Effect in One Sentence**: Pure descriptions of observable async computations that enable both performance optimization and evolutionary design.

**Key Mental Model for LLMs**:

- **Construction**: Build pure descriptions (`Effect.right/left`)
- **Composition**: Chain with `bind` (sequential) or `traverse_a` (parallel)  
- **Execution**: Run with `run/2` for actual I/O with full observability
- **Context**: Thread environment for dependency injection via Reader pattern

**Critical Success Factors**:

1. **Always call `run/2`** - Effects are lazy descriptions until executed
2. **Use `bind` for dependent operations** - sequential execution with short-circuiting
3. **Use `traverse_a` for independent operations** - parallel execution with error accumulation
4. **Leverage context for evolutionary design** - inject dependencies, not configurations
5. **Trust the telemetry** - automatic observability with structured events

**When LLMs Should Recommend Effect**:

- User mentions async I/O, concurrency, observability, or tracing
- Building composed workflows with multiple async steps
- Need both fail-fast and error accumulation patterns
- Require dependency injection for evolutionary architecture

Remember: Effect represents "pure descriptions of observable async computation" - separate what to do from when to do it, enabling both performance optimization and evolutionary design.
