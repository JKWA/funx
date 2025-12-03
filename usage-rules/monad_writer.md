# `Funx.Monad.Writer` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Writer**: Represents computation with accumulated log alongside result

- `pure(value)` creates a Writer with value and empty log
- `writer({value, log})` creates a Writer with both value and log
- `tell(log)` emits log entry with `:ok` value
- `run(writer)` executes and returns `%Result{value: v, log: l}`

**Log Accumulation**: Monoid-based log threading through computation

- Log accumulated using Monoid (default: ListConcat for lists)
- Each operation can add to the log via `tell/1`
- Log preserved and combined through `map/2`, `bind/2`, `ap/2`
- **Key insight**: Eliminates manual log threading and ensures logs aren't lost

## Core Operations

### `tap/2` - Side Effects Without Affecting Log

Executes a side-effect function on the value and returns the original Writer unchanged. **Does NOT add to the Writer's log** - use `tell/1` if you want to log:

```elixir
import Funx.Monad.Writer

# Side effect that doesn't add to log
Writer.pure(42)
|> Writer.tap(&IO.inspect(&1, label: "debug"))  # Prints "debug: 42"
|> Writer.run()
# Returns: %Result{value: 42, log: []}  # No log entry!

# Compare with tell (adds to log)
Writer.pure(42)
|> Writer.bind(fn x ->
  Writer.tell(["processed #{x}"])
  |> Writer.map(fn _ -> x end)
end)
|> Writer.run()
# Returns: %Result{value: 42, log: ["processed 42"]}
```

**Use `tap` when:**

- Debugging Writer pipelines - inspect values without polluting the log
- External side effects - IO, logging to external systems, metrics
- Observing values without changing Writer state
- Side effects that shouldn't be part of the monadic log

**Common tap patterns:**

```elixir
# Debug without adding to log
Writer.pure(data)
|> Writer.tap(&IO.inspect(&1, label: "before processing"))
|> Writer.bind(&process_with_logging/1)  # This adds to log
|> Writer.tap(&IO.inspect(&1, label: "after processing"))
|> Writer.run()

# External logging (not in Writer log)
Writer.writer({order, ["created"]})
|> Writer.tap(fn o -> Logger.info("Processing order #{o.id}") end)
|> Writer.bind(&charge_payment/1)  # Adds to Writer log
|> Writer.run()

# Telemetry (separate from Writer log)
Writer.pure(calculation_result)
|> Writer.tap(fn result ->
  :telemetry.execute([:app, :calc], %{value: result})
end)
|> Writer.run()
```

**Important notes:**

- The function's return value is discarded
- **Does NOT add to Writer's log** - use `tell/1` for that
- Useful for side effects that are separate from the computation's log
- Writer's log is for domain/business logging, `tap` is for debugging/external effects

### Distinction: `tap` vs `tell`

```elixir
# tap - side effect, NO log entry
Writer.pure(42)
|> Writer.tap(fn x -> IO.puts("Value: #{x}") end)  # Prints, but...
|> Writer.run()
# %Result{value: 42, log: []}  # ...no log entry

# tell - adds to Writer's log
Writer.pure(42)
|> Writer.bind(fn x ->
  Writer.tell(["processing: #{x}"])
  |> Writer.map(fn _ -> x end)
end)
|> Writer.run()
# %Result{value: 42, log: ["processing: 42"]}  # Log entry!
```

**When to use which:**
- **`tap`**: Debugging, external logging, metrics, IO - things outside the Writer's domain
- **`tell`**: Domain events, business log, audit trail - things that are part of the computation's story
