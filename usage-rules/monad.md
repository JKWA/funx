# `Funx.Monad` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Monad**: A design pattern that provides a structured way to handle computations with context

- **Bind operation**: Chains computations that might fail, transform, or have side effects
- **Map operation**: Transforms the wrapped value with a regular function
- **Mathematical foundation**: Satisfies identity and associativity laws
- **Three fundamental operations**: `bind/2`, `map/2`, and `ap/2`

**Kleisli Functions**: Functions that return values wrapped in a monadic context

- Type signature: `a -> M<b>` (takes regular value, returns monadic value)
- Compose with `bind/2` rather than regular function composition
- Enable chaining of operations that might fail or transform context
- Example: `fn x -> {:ok, x * 2} end` is a Kleisli function for Result monad

**Monadic vs. Applicative**: Different styles for handling multiple wrapped values

- **Monadic (sequential)**: Later computations depend on earlier results
- **Applicative (independent)**: All computations are independent and *can* run in parallel
- **Concurrency note**: Parallel execution only applies to Effect monad - Maybe/Either are synchronous
- **Rule**: Use monadic when you need the result of one computation to determine the next

**Bind vs. Map**: Different operations for different transformations

- **Map**: Transform the value inside the monad (`a -> b` functions)
- **Bind**: Chain monadic operations (`a -> M<b>` functions)
- **Key insight**: Bind flattens nested monads, map doesn't

**Context Preservation**: Monads maintain computational context through transformations

- **Maybe monad**: Preserves presence/absence context (synchronous)
- **Either monad**: Preserves success/failure with error information (synchronous)
- **Effect monad**: Preserves async computation with Reader environment (deferred/concurrent)
- **Identity monad**: Transparent context for learning and composition (synchronous)
- **Context flows**: Through bind chains automatically

## LLM Decision Guide: When to Use Monad Protocol

**✅ Use Monad Protocol when:**

- Building generic functions that work with any monad
- Creating monad-agnostic algorithms
- Need to compose different monadic operations
- Want polymorphic code that works with Maybe, Either, Identity, etc.
- User says: "generic", "polymorphic", "works with any monad", "monad-agnostic"

**❌ Don't use Protocol when:**

- Working with specific monad types only
- Performance is critical (protocol dispatch has overhead)
- Simple transformations that don't need genericity
- User is asking for specific Maybe or Either operations

**⚡ Protocol vs. Direct Module Decision:**

- **Protocol**: Generic code that works with multiple monad types
- **Direct module**: Type-specific optimized operations
- **Rule**: Start with direct modules, extract to protocol when you need genericity

**⚙️ Operation Choice Guide:**

- **bind/2**: Chain operations that return monadic values
- **map/2**: Transform values inside the monadic context
- **ap/2**: Apply functions in monadic context to values in monadic context
- **Law verification**: Always test monad laws in generic code

## LLM Context Clues

**User language → Monad protocol patterns:**

- "generic monad function" → Use protocol operations
- "works with any monad" → Protocol-based implementation
- "polymorphic over monads" → Protocol with type constraints
- "chain operations" → `bind/2` sequences
- "transform value" → `map/2`
- "apply function" → `ap/2`
- "sequence computations" → Bind chains with error handling
- "monad laws" → Identity and associativity verification

## Quick Reference

- Use `bind/2` to chain Kleisli functions (operations returning monadic values)
- Use `map/2` to transform values inside the monadic context
- Use `ap/2` for applicative style when computations are independent
- Use constructor functions like `Maybe.just/1`, `Either.right/1` to create monadic values
- Use `bind/2` to naturally flatten nested monads through composition
- All monads support `map/2` and `ap/2` via protocol or import
- Monad laws: left identity, right identity, associativity
- Protocol enables polymorphic functions working across monad types

## Overview

`Funx.Monad` defines the core protocol for monadic operations in Elixir. It provides the essential operations that all monads must implement: `bind/2`, `map/2`, and `ap/2`. This protocol enables writing generic, reusable functions that work with any monadic type.

The protocol is the foundation for functional composition patterns, enabling you to chain computations while preserving context (whether that's handling optional values, errors, transformations, or other computational contexts).

## Protocol Operations

| Operation    | Type Signature              | Purpose                                    |
| ------------ | --------------------------- | ------------------------------------------ |
| `bind/2`     | `M<a> -> (a -> M<b>) -> M<b>` | Chain monadic computations                 |
| `map/2`      | `M<a> -> (a -> b) -> M<b>`  | Transform the wrapped value                |
| `ap/2`       | `M<(a -> b)> -> M<a> -> M<b>` | Apply a wrapped function to wrapped value |

The protocol requires implementing three operations: `bind/2` for chaining monadic functions, `map/2` for transforming wrapped values, and `ap/2` for applicative-style function application.

## LLM Monad Laws Foundation

**Mathematical Requirements:**

All monad implementations must satisfy three fundamental laws:

**Left Identity**: `Constructor.new(a) |> bind(f) == f.(a)`

- Creating a monad then binding should equal direct application
- The monadic wrapper doesn't interfere with computation

**Right Identity**: `m |> bind(fn x -> Constructor.new(x) end) == m`  

- Binding with constructor should leave the monad unchanged
- Constructor functions are neutral elements for bind

**Associativity**: `(m |> bind(f)) |> bind(g) == m |> bind(fn x -> bind(f.(x), g) end)`

- Order of binding operations doesn't matter
- Enables reliable composition and refactoring

**Why Laws Matter for LLMs:**

- **Predictability**: Laws ensure consistent behavior across implementations
- **Composition safety**: Can refactor and compose without breaking semantics  
- **Generic algorithms**: Enable writing functions that work with any lawful monad
- **Debugging confidence**: Law violations indicate implementation bugs

## Usage Patterns

### Basic Monadic Pipeline

```elixir
# Generic function working with any monad
def transform_generically(monad_value) do
  monad_value
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x * 2) end)
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
  |> Monad.bind(fn x -> 
    if x > 10 do
      SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc."large: #{x}")
    else
      SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc."small: #{x}")
    end
  end)
end

# Works with Maybe
transform_generically(Maybe.just(5))    # => Just("large: 11") 
transform_generically(Maybe.nothing())  # => Nothing

# Works with Either  
transform_generically(Either.right(5))  # => Right("large: 11")
transform_generically(Either.left("error")) # => Left("error")
```

### Kleisli Function Composition

```elixir
# Kleisli functions for various monads
def safe_divide(a, b) do
  if b != 0 do
    Maybe.just(a / b)
  else
    Maybe.nothing()
  end
end

def validate_positive(x) do
  if x > 0 do
    Either.right(x)
  else
    Either.left("must be positive")
  end
end

# Generic composition using protocol
def compose_kleisli(value, kleisli_fns) do
  Enum.reduce(kleisli_fns, SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.value), fn f, acc ->
    Monad.bind(acc, f)
  end)
end

# Use with different monads
compose_kleisli(10, [safe_divide(20), &Maybe.just(&1 + 1)])
compose_kleisli(10, [validate_positive, fn x -> Either.right(x * 2) end])
```

### Map for Transforming Values

```elixir
# Transform values inside monadic context
import Funx.Monad

# Works with any monad
Maybe.just(5) |> map(&(&1 * 2))      # Just(10)
Either.right(5) |> map(&(&1 * 2))    # Right(10)
Identity.identity(5) |> map(&(&1 * 2)) # Identity(10)

# Chain transformations
Maybe.just("hello")
|> map(&String.upcase/1)              # Just("HELLO")
|> map(&String.length/1)              # Just(5)
```

### Ap for Applying Wrapped Functions

Applies a monadic function (e.g., `M<(a -> b)>`) to a monadic argument (`M<a>`), returning `M<b>`. This enables applicative style when computations are independent.

```elixir
import Funx.Monad

# Basic function application
add = fn x -> fn y -> x + y end end

return(add)
|> ap(return(3))
|> ap(return(4))                     # Works with any monad

# With Maybe
Maybe.just(add)
|> ap(Maybe.just(3))
|> ap(Maybe.just(4))                 # Just(7)

# With Either
Either.right(add)
|> ap(Either.right(3))
|> ap(Either.right(4))               # Right(7)

# String concatenation
concat3 = fn a -> fn b -> fn c -> a <> b <> c end end end

Maybe.just(concat3)
|> ap(Maybe.just("Hello, "))
|> ap(Maybe.just("World"))
|> ap(Maybe.just("!"))               # Just("Hello, World!")
```

### Flattening Nested Monads

```elixir
# When you have nested monads - use bind to flatten naturally
nested_maybe = Maybe.just(Maybe.just(42))
flattened = Monad.bind(nested_maybe, fn inner -> inner end)  # => Just(42)

nested_either = Either.right(Either.right("success"))
flattened = Monad.bind(nested_either, fn inner -> inner end)  # => Right("success")
```

## Guidelines for Generic Monad Functions

When writing functions that work with any monad:

- **Use protocol operations only**: `Monad.bind/2`, `Monad.map/2`, `Monad.ap/2`
- **Avoid specific monad constructors**: Don't use `Maybe.just/1` in generic code
- **Choose the right operation**: `map` for transforming, `bind` for chaining, `ap` for independent computations
- **Test monad laws**: Verify your functions preserve monadic structure  
- **Consider performance**: Protocol dispatch has overhead vs direct module calls
- **Document type constraints**: Make clear which monads your function supports
- **Handle all cases**: Generic code should work correctly with all monadic types

## LLM Code Templates

### Basic Monadic Pipeline Template

```elixir
def build_monadic_pipeline() do
  fn initial_value, monad_type ->
    initial_value
    |> monad_type.return()
    |> Monad.bind(fn x -> 
      # First transformation (returns monadic value)
      transformed = transform_step_1(x)
      monad_type.return(transformed)
    end)
    |> Monad.bind(fn x ->
      # Second transformation with possible failure
      case validate_step_2(x) do
        :ok -> monad_type.return(x)
        {:error, reason} -> monad_type.error(reason)  # Assumes error constructor
      end
    end)
    |> Monad.bind(fn x ->
      # Final transformation
      result = finalize_step(x)
      monad_type.return(result)
    end)
  end
end

# Usage with different monads
pipeline = build_monadic_pipeline()
pipeline.(42, Maybe)   # Works with Maybe monad
pipeline.(42, Either)  # Works with Either monad
```

### Monad Law Verification Template

```elixir
def verify_monad_laws(monad_module, test_value, test_function) do
  # Left Identity Law: return(a) >>= f === f(a)
  left_identity = fn ->
    left = monad_module.return(test_value) |> Monad.bind(test_function)
    right = test_function.(test_value)
    left == right
  end
  
  # Right Identity Law: m >>= return === m  
  right_identity = fn ->
    test_monad = monad_module.return(test_value)
    left = test_monad |> Monad.bind(&monad_module.return/1)
    right = test_monad
    left == right
  end
  
  # Associativity Law: (m >>= f) >>= g === m >>= (\x -> f(x) >>= g)
  associativity = fn ->
    test_monad = monad_module.return(test_value)
    second_function = fn x -> monad_module.return(x * 3) end
    
    left = test_monad
           |> Monad.bind(test_function) 
           |> Monad.bind(second_function)
    
    right = test_monad |> Monad.bind(fn x ->
      test_function.(x) |> Monad.bind(second_function)
    end)
    
    left == right
  end
  
  %{
    left_identity: left_identity.(),
    right_identity: right_identity.(),
    associativity: associativity.()
  }
end

# Test all laws for a monad
def test_monad_implementation(monad_module) do
  test_fn = fn x -> monad_module.return(x + 1) end
  results = verify_monad_laws(monad_module, 42, test_fn)
  
  all_passed = Enum.all?(Map.values(results))
  {all_passed, results}
end
```

### Kleisli Function Factory Template

```elixir
def build_kleisli_factory(monad_module) do
  %{
    # Safe mathematical operations
    safe_divide: fn a, b ->
      if b != 0 do
        monad_module.return(a / b)
      else
        monad_module.error("division by zero")
      end
    end,
    
    safe_sqrt: fn x ->
      if x >= 0 do
        monad_module.return(:math.sqrt(x))
      else
        monad_module.error("negative square root")
      end
    end,
    
    # Validation operations
    validate_range: fn min, max ->
      fn value ->
        if value >= min and value <= max do
          monad_module.return(value)
        else
          monad_module.error("value #{value} not in range #{min}-#{max}")
        end
      end
    end,
    
    # Transformation operations
    transform_with: fn transformer ->
      fn value ->
        try do
          result = transformer.(value)
          monad_module.return(result)
        rescue
          error -> monad_module.error("transformation failed: #{inspect(error)}")
        end
      end
    end,
    
    # Conditional operations
    when_condition: fn predicate, then_fn, else_fn ->
      fn value ->
        if predicate.(value) do
          then_fn.(value)
        else
          else_fn.(value)
        end
      end
    end
  }
end

# Usage with different monads
maybe_ops = build_kleisli_factory(Maybe)
either_ops = build_kleisli_factory(Either)

# Chain operations
42
|> maybe_ops.safe_divide.(6)
|> Monad.bind(maybe_ops.safe_sqrt)
|> Monad.bind(maybe_ops.validate_range.(0, 10))
```

### Applicative vs. Monadic Style Template

```elixir
def comparison_template() do
  import Funx.Monad
  
  # Sample data
  maybe_a = Maybe.just(5)
  maybe_b = Maybe.just(10)
  maybe_c = Maybe.just(2)
  
  # Applicative style - all computations are independent
  add3 = fn a -> fn b -> fn c -> a + b + c end end end
  applicative_result = 
    return(add3)
    |> ap(maybe_a)
    |> ap(maybe_b)
    |> ap(maybe_c)  # Just(17)
  
  # Monadic style - later computations depend on earlier ones
  monadic_result = 
    maybe_a
    |> bind(fn a ->
      maybe_b |> bind(fn b ->
        # This computation depends on both a and b
        if a + b > 10 do
          maybe_c |> bind(fn c ->
            return(a + b + c + 100)  # Bonus for large values
          end)
        else
          maybe_c |> bind(fn c ->
            return(a + b + c)
          end)
        end
      end)
    end)
  
  # When to use each:
  # - Applicative: When operations are independent (use ap)
  # - Monadic: When later operations depend on earlier results (use bind)
  
  %{
    applicative: applicative_result,  # Just(17)
    monadic: monadic_result          # Just(117) - includes bonus
  }
end
```

### Monad Transformer Pattern Template

```elixir
def build_transformer_stack() do
  # Example: Maybe + IO monad transformer
  # MaybeT IO a = IO (Maybe a)
  
  # Basic operations for the transformer
  def lift_io(io_action) do
    fn -> 
      result = io_action.()
      Maybe.just(result)
    end
  end
  
  def lift_maybe(maybe_value) do
    fn -> maybe_value end
  end
  
  # Bind for the transformer stack
  def bind_transformer(transformer_action, kleisli_fn) do
    fn ->
      case transformer_action.() do
        Maybe.Nothing -> Maybe.nothing()
        Maybe.Just(value) ->
          next_action = kleisli_fn.(value)
          next_action.()
      end
    end
  end
  
  # Example usage
  def fetch_and_process_user(user_id) do
    # This would be a complex operation involving both IO and Maybe
    lift_io(fn -> fetch_user_from_db(user_id) end)
    |> bind_transformer(fn user ->
      if user.active do
        lift_maybe(Maybe.just(user))
      else
        lift_maybe(Maybe.nothing())
      end
    end)
    |> bind_transformer(fn user ->
      lift_io(fn -> 
        processed_user = process_user_data(user)
        Maybe.just(processed_user)
      end)
    end)
  end
  
  # Run the transformer stack
  user_result = fetch_and_process_user(123)
  final_result = user_result.()  # IO (Maybe User)
end
```

### Utils Integration Template

```elixir
def build_utils_integration() do
  # Combine Monad protocol with Utils currying
  
  # Curry monadic operations for pipeline use
  bind_with = Funx.Utils.curry_r(&Monad.bind/2)
  
  # Create reusable monadic operations
  def create_monadic_validators() do
    %{
      positive: bind_with.(fn x ->
        if x > 0 do
          Maybe.just(x)
        else
          Maybe.nothing()
        end
      end),
      
      even: bind_with.(fn x ->
        if rem(x, 2) == 0 do
          Either.right(x)
        else
          Either.left("must be even")
        end
      end),
      
      in_range: fn min, max ->
        bind_with.(fn x ->
          if x >= min and x <= max do
            Maybe.just(x)
          else
            Maybe.nothing()
          end
        end)
      end
    }
  end
  
  # Use in pipelines
  validators = create_monadic_validators()
  
  # Pipeline with curried monadic operations
  result = Maybe.just(42)
           |> validators.positive.()
           |> bind_with.(fn x -> Maybe.just(x * 2) end).()
           |> validators.in_range.(50, 100).()
  
  # Compose multiple validators
  validate_positive_even = fn monad_value ->
    monad_value
    |> validators.positive.()
    |> validators.even.()
  end
  
  Either.right(20) |> validate_positive_even.()
end
```

## LLM Testing Guidance

### Test Protocol Implementation

```elixir
defmodule MonadLawTest do
  use ExUnit.Case
  
  # Test that a monad implementation satisfies the laws
  def test_monad_laws(monad_module, sample_values, sample_functions) do
    Enum.each(sample_values, fn value ->
      Enum.each(sample_functions, fn f ->
        test_left_identity(monad_module, value, f)
        test_right_identity(monad_module, value)
        test_associativity(monad_module, value, f)
      end)
    end)
  end
  
  defp test_left_identity(monad_module, value, kleisli_fn) do
    # return(a) >>= f === f(a)
    left = monad_module.return(value) |> Monad.bind(kleisli_fn)
    right = kleisli_fn.(value)
    
    assert left == right, """
    Left identity law failed for #{inspect(monad_module)}
    Value: #{inspect(value)}
    Function: #{inspect(kleisli_fn)}
    """
  end
  
  defp test_right_identity(monad_module, value) do
    # m >>= return === m
    monad_value = monad_module.return(value)
    left = monad_value |> Monad.bind(&monad_module.return/1)
    right = monad_value
    
    assert left == right, """
    Right identity law failed for #{inspect(monad_module)}
    Value: #{inspect(value)}
    """
  end
  
  defp test_associativity(monad_module, value, f) do
    # (m >>= f) >>= g === m >>= (\x -> f(x) >>= g)
    g = fn x -> monad_module.return(x * 3) end
    m = monad_module.return(value)
    
    left = m |> Monad.bind(f) |> Monad.bind(g)
    right = m |> Monad.bind(fn x -> f.(x) |> Monad.bind(g) end)
    
    assert left == right, """
    Associativity law failed for #{inspect(monad_module)}
    Value: #{inspect(value)}
    """
  end
  
  test "Maybe satisfies monad laws" do
    sample_values = [1, 2, 0, -1, 100]
    sample_functions = [
      fn x -> Maybe.just(x + 1) end,
      fn x -> if x > 0, do: Maybe.just(x), else: Maybe.nothing() end,
      fn x -> Maybe.just(x * 2) end
    ]
    
    test_monad_laws(Maybe, sample_values, sample_functions)
  end
  
  test "Either satisfies monad laws" do
    sample_values = [1, 2, 0, -1]
    sample_functions = [
      fn x -> Either.right(x + 1) end,
      fn x -> if x >= 0, do: Either.right(x), else: Either.left("negative") end,
      fn x -> Either.right(x * 2) end
    ]
    
    test_monad_laws(Either, sample_values, sample_functions)
  end
end
```

### Test Generic Monadic Functions

```elixir
defmodule GenericMonadTest do
  use ExUnit.Case
  
  # Test that generic functions work with multiple monad types
  def generic_double_and_add(monad_value, amount) do
    monad_value
    |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x * 2) end)
    |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + amount) end)
  end
  
  test "generic functions work with Maybe" do
    result = generic_double_and_add(Maybe.just(5), 10)
    assert result == Maybe.just(20)
    
    result = generic_double_and_add(Maybe.nothing(), 10)
    assert result == Maybe.nothing()
  end
  
  test "generic functions work with Either" do
    result = generic_double_and_add(Either.right(5), 10)
    assert result == Either.right(20)
    
    result = generic_double_and_add(Either.left("error"), 10)
    assert result == Either.left("error")
  end
  
  test "generic functions work with Identity" do
    result = generic_double_and_add(Identity.new(5), 10)
    assert result == Identity.new(20)
  end
end
```

### Test Join Operation

```elixir
defmodule MonadJoinTest do
  use ExUnit.Case
  
  test "join flattens nested Maybe" do
    nested = Maybe.just(Maybe.just(42))
    flattened = Monad.bind(nested, fn inner -> inner end)
    assert flattened == Maybe.just(42)
    
    nested_nothing_inner = Maybe.just(Maybe.nothing())
    flattened = Monad.bind(nested_nothing_inner, fn inner -> inner end)
    assert flattened == Maybe.nothing()
    
    nothing_outer = Maybe.nothing()
    flattened = Monad.bind(nothing_outer, fn inner -> inner end)
    assert flattened == Maybe.nothing()
  end
  
  test "join flattens nested Either" do
    nested_right = Either.right(Either.right("success"))
    flattened = Monad.bind(nested_right, fn inner -> inner end)
    assert flattened == Either.right("success")
    
    nested_left_inner = Either.right(Either.left("inner error"))
    flattened = Monad.bind(nested_left_inner, fn inner -> inner end)
    assert flattened == Either.left("inner error")
    
    left_outer = Either.left("outer error")
    flattened = Monad.bind(left_outer, fn inner -> inner end)
    assert flattened == Either.left("outer error")
  end
end
```

## LLM Debugging Tips

### Trace Monadic Operations

```elixir
def trace_monad_operations(monad_value, operations) do
  IO.puts("Starting with: #{inspect(monad_value)}")
  
  result = Enum.reduce(operations, {monad_value, 0}, fn operation, {current, step} ->
    IO.puts("Step #{step}: Input = #{inspect(current)}")
    
    next = case operation do
      {:bind, f} -> 
        result = Monad.bind(current, f)
        IO.puts("Step #{step}: bind -> #{inspect(result)}")
        result
      {:map, f} ->
        result = Monad.bind(current, fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.f.(x)) end)
        IO.puts("Step #{step}: map -> #{inspect(result)}")
        result
    end
    
    {next, step + 1}
  end)
  
  {traced_result, _} = result
  IO.puts("Final result: #{inspect(traced_result)}")
  traced_result
end

# Usage
trace_monad_operations(Maybe.just(10), [
  {:bind, fn x -> Maybe.just(x * 2) end},
  {:map, fn x -> x + 5 end},
  {:bind, fn x -> if x > 20, do: Maybe.just(x), else: Maybe.nothing() end}
])
```

### Verify Law Compliance

```elixir
def debug_monad_laws(monad_module, value, function) do
  IO.puts("Testing monad laws for #{inspect(monad_module)} with value #{inspect(value)}")
  
  # Left Identity
  left_identity_left = monad_module.return(value) |> Monad.bind(function)
  left_identity_right = function.(value)
  left_identity_ok = left_identity_left == left_identity_right
  
  IO.puts("Left Identity: #{left_identity_ok}")
  IO.puts("  return(#{inspect(value)}) >>= f = #{inspect(left_identity_left)}")
  IO.puts("  f(#{inspect(value)}) = #{inspect(left_identity_right)}")
  
  # Right Identity
  m = monad_module.return(value)
  right_identity_left = m |> Monad.bind(&monad_module.return/1)
  right_identity_right = m
  right_identity_ok = right_identity_left == right_identity_right
  
  IO.puts("Right Identity: #{right_identity_ok}")
  IO.puts("  m >>= return = #{inspect(right_identity_left)}")
  IO.puts("  m = #{inspect(right_identity_right)}")
  
  # Associativity
  g = fn x -> monad_module.return(x + 100) end
  assoc_left = m |> Monad.bind(function) |> Monad.bind(g)
  assoc_right = m |> Monad.bind(fn x -> function.(x) |> Monad.bind(g) end)
  associativity_ok = assoc_left == assoc_right
  
  IO.puts("Associativity: #{associativity_ok}")
  IO.puts("  (m >>= f) >>= g = #{inspect(assoc_left)}")
  IO.puts("  m >>= (\\x -> f(x) >>= g) = #{inspect(assoc_right)}")
  
  %{
    left_identity: left_identity_ok,
    right_identity: right_identity_ok,
    associativity: associativity_ok,
    all_pass: left_identity_ok and right_identity_ok and associativity_ok
  }
end
```

### Monitor Performance

```elixir
def benchmark_monadic_operations() do
  # Compare protocol vs direct module performance
  test_value = Maybe.just(42)
  iterations = 100_000
  
  # Protocol-based version
  protocol_time = :timer.tc(fn ->
    for _ <- 1..iterations do
      test_value
      |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
      |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x * 2) end)
    end
  end)
  
  # Direct module version
  direct_time = :timer.tc(fn ->
    for _ <- 1..iterations do
      test_value
      |> Maybe.bind(fn x -> Maybe.just(x + 1) end)
      |> Maybe.bind(fn x -> Maybe.just(x * 2) end)
    end
  end)
  
  IO.puts("Protocol time: #{elem(protocol_time, 0)} microseconds")
  IO.puts("Direct time: #{elem(direct_time, 0)} microseconds")
  IO.puts("Overhead: #{(elem(protocol_time, 0) / elem(direct_time, 0) - 1) * 100}%")
end
```

## LLM Common Mistakes to Avoid

### ❌ Don't Mix Protocol and Direct Calls

```elixir
# ❌ Wrong: mixing protocol and module-specific calls
def bad_generic_function(monad_value) do
  monad_value
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
  |> Maybe.map(fn x -> x * 2 end)  # Breaks genericity!
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x - 1) end)
end

# ✅ Correct: use protocol operations consistently  
def good_generic_function(monad_value) do
  monad_value
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x * 2) end)  # Map via bind + return
  |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x - 1) end)
end
```

### ❌ Don't Assume Specific Monad Constructors

```elixir
# ❌ Wrong: using specific constructors in generic code
def bad_validate_positive(monad_value) do
  Monad.bind(monad_value, fn x ->
    if x > 0 do
      Maybe.just(x)  # Assumes Maybe monad!
    else
      Maybe.nothing()
    end
  end)
end

# ✅ Correct: use protocol operations and pass monad module
def good_validate_positive(monad_value, monad_module) do
  Monad.bind(monad_value, fn x ->
    if x > 0 do
      monad_module.return(x)
    else
      monad_module.empty()  # Assumes empty/error constructor
    end
  end)
end
```

### ❌ Don't Ignore Monad Laws

```elixir
# ❌ Wrong: implementing bind that violates laws
defmodule BadMonad do
  defstruct [:value, :extra]
  
  defimpl Funx.Monad do
    def bind(%BadMonad{value: value, extra: extra}, f) do
      # This breaks associativity by adding extra each time!
      result = f.(value)
      %{result | extra: extra + 1}
    end
    
    def return(value), do: %BadMonad{value: value, extra: 0}
    def join(%BadMonad{value: %BadMonad{} = inner}), do: inner
  end
end

# ✅ Correct: law-abiding implementation
defmodule GoodMonad do
  defstruct [:value]
  
  defimpl Funx.Monad do
    def bind(%GoodMonad{value: value}, f) do
      f.(value)  # Simple, law-abiding bind
    end
    
    def return(value), do: %GoodMonad{value: value}
    def join(%GoodMonad{value: %GoodMonad{} = inner}), do: inner
  end
end
```

### ❌ Don't Use Return Inside Bind Unnecessarily

```elixir
# ❌ Wrong: unnecessary return wrapping
def bad_chain(monad_value) do
  monad_value
  |> Monad.bind(fn x ->
    result = x + 1
    SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.result)  # This is just map!
  end)
end

# ✅ Better: recognize this is mapping, not binding
def good_chain(monad_value) do
  # If your monad has map, use it
  monad_value |> SomeMonad.map(fn x -> x + 1 end)
  
  # Or if you need generic protocol:
  monad_value |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
end

# ✅ Best: only use bind when you need to flatten
def best_chain(monad_value) do
  monad_value
  |> Monad.bind(fn x ->
    # This function returns a monad, so bind is correct
    if x > 0 do
      SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x)
    else
      SomeMonad.empty()
    end
  end)
end
```

### ❌ Don't Nest Binds When You Can Chain

```elixir
# ❌ Wrong: nested bind calls (hard to read)
def bad_nested_operations(monad_value) do
  Monad.bind(monad_value, fn x ->
    Monad.bind(SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1), fn y ->
      Monad.bind(SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.y * 2), fn z ->
        SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.z - 1)
      end)
    end)
  end)
end

# ✅ Correct: chain bind operations with pipe
def good_chained_operations(monad_value) do
  monad_value
  |> Monad.bind(fn x -> SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
  |> Monad.bind(fn y -> SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.y * 2) end) 
  |> Monad.bind(fn z -> SomeSpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.z - 1) end)
end
```

### ❌ Don't Forget Error Propagation

```elixir
# ❌ Wrong: not handling error cases in generic code
def bad_error_handling(monad_value) do
  Monad.bind(monad_value, fn x ->
    # What if this operation can fail?
    result = risky_operation(x)  # Might raise exception
    SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.result)
  end)
end

# ✅ Correct: handle errors appropriately
def good_error_handling(monad_value, monad_module) do
  Monad.bind(monad_value, fn x ->
    try do
      result = risky_operation(x)
      monad_module.return(result)
    rescue
      error -> monad_module.error("operation failed: #{inspect(error)}")
    end
  end)
end
```

## LLM Integration with Other Modules

### With Predicate Logic

```elixir
def build_predicate_monadic_filters() do
  # Combine predicates with monadic validation
  
  # Create monadic validators from predicates
  def predicate_to_monad_validator(predicate, error_msg) do
    fn value ->
      if Predicate.test(predicate, value) do
        Maybe.just(value)
      else
        Either.left(error_msg)
      end
    end
  end
  
  # Build complex validation chains
  age_predicate = Predicate.Utils.and_all([
    Predicate.Utils.greater_than(0),
    Predicate.Utils.less_than(150)
  ])
  
  email_predicate = Predicate.Utils.matches(~r/@/)
  
  validators = %{
    age: predicate_to_monad_validator(age_predicate, "invalid age"),
    email: predicate_to_monad_validator(email_predicate, "invalid email")
  }
  
  # Use in monadic pipeline
  def validate_user(user_data) do
    {:ok, user_data}
    |> Either.from_result()
    |> Monad.bind(fn data ->
      validators.age.(data.age)
      |> Monad.bind(fn _ -> validators.email.(data.email))
      |> Monad.bind(fn _ -> Either.right(data))
    end)
  end
  
  validate_user(%{age: 25, email: "user@example.com"})
end
```

### With Utils Currying

```elixir
def build_curried_monadic_operations() do
  # Create curried monadic operations for pipeline use
  
  # Curry bind for different argument orders
  bind_with_fn = Funx.Utils.curry_r(&Monad.bind/2)
  bind_with_monad = Funx.Utils.curry(&Monad.bind/2)
  
  # Create reusable monadic transformations
  def create_transformers() do
    %{
      validate_positive: bind_with_fn.(fn x ->
        if x > 0 do
          Maybe.just(x)
        else
          Maybe.nothing()
        end
      end),
      
      safe_divide_by: fn divisor ->
        bind_with_fn.(fn x ->
          if divisor != 0 do
            Maybe.just(x / divisor)
          else
            Maybe.nothing()
          end
        end)
      end,
      
      transform_with: fn transformer ->
        bind_with_fn.(fn x ->
          try do
            result = transformer.(x)
            Maybe.just(result)
          rescue
            _ -> Maybe.nothing()
          end
        end)
      end
    }
  end
  
  # Use in functional pipelines
  transformers = create_transformers()
  
  Maybe.just(42)
  |> transformers.validate_positive.()
  |> transformers.safe_divide_by.(6).()
  |> transformers.transform_with.(&round/1).()
end
```

### With Eq for Custom Equality

```elixir
def build_monadic_equality_operations() do
  # Use custom Eq instances in monadic contexts
  
  # Create monadic equality testers
  def create_equality_validators(eq_instance) do
    %{
      equals: fn expected_value ->
        fn monad_value ->
          Monad.bind(monad_value, fn actual_value ->
            if Eq.Utils.eq?(actual_value, expected_value, eq_instance) do
              Maybe.just(actual_value)
            else
              Maybe.nothing()
            end
          end)
        end
      end,
      
      not_equals: fn forbidden_value ->
        fn monad_value ->
          Monad.bind(monad_value, fn actual_value ->
            if Eq.Utils.not_eq?(actual_value, forbidden_value, eq_instance) do
              Maybe.just(actual_value)
            else
              Maybe.nothing()
            end
          end)
        end
      end
    }
  end
  
  # Use with custom Eq instances
  by_id_eq = Eq.Utils.contramap(fn user -> user.id end)
  validators = create_equality_validators(by_id_eq)
  
  target_user = %{id: 123, name: "Alice"}
  forbidden_user = %{id: 999, name: "Admin"}
  
  Maybe.just(%{id: 123, name: "Alice Updated"})
  |> validators.equals.(target_user).()  # Passes (same ID)
  |> validators.not_equals.(forbidden_user).()  # Passes (different ID)
end
```

### Cross-Module Composition

```elixir
def build_comprehensive_pipeline() do
  # Combine Monad, Predicate, Utils, and Eq in one pipeline
  
  # Setup components
  age_predicate = Predicate.Utils.between(18, 65)
  email_predicate = Predicate.Utils.matches(~r/\A[^@\s]+@[^@\s]+\z/)
  user_eq = Eq.Utils.contramap(fn user -> {user.id, user.email} end)
  
  # Curried operations
  validate_with = Funx.Utils.curry_r(fn predicate, value ->
    if Predicate.test(predicate, value) do
      Either.right(value)
    else
      Either.left("validation failed")
    end
  end)
  
  transform_with = Funx.Utils.curry_r(fn transformer, monad_value ->
    Monad.bind(monad_value, fn value ->
      Either.right(transformer.(value))
    end)
  end)
  
  # Build comprehensive validation pipeline
  def validate_and_transform_user(user_data, existing_users) do
    user_data
    |> Either.right()
    |> Monad.bind(validate_with.(age_predicate).(user_data.age))
    |> Monad.bind(validate_with.(email_predicate).(user_data.email))
    |> transform_with.(fn data -> 
      %{data | name: String.upcase(data.name)}
    end).()
    |> Monad.bind(fn processed_user ->
      # Check for duplicates using custom Eq
      duplicate = Enum.find(existing_users, fn existing ->
        Eq.Utils.eq?(processed_user, existing, user_eq)
      end)
      
      if duplicate do
        Either.left("duplicate user")
      else
        Either.right(processed_user)
      end
    end)
  end
  
  # Usage
  new_user = %{id: 123, name: "alice", age: 25, email: "alice@example.com"}
  existing = [%{id: 456, name: "bob", age: 30, email: "bob@example.com"}]
  
  validate_and_transform_user(new_user, existing)
end
```

## Performance Considerations

### Protocol Overhead

Protocol dispatch has performance overhead compared to direct module calls:

```elixir
# Benchmark protocol vs direct calls
def benchmark_monad_operations() do
  test_value = Maybe.just(42)
  iterations = 100_000
  
  # Protocol version
  protocol_fun = fn ->
    Enum.reduce(1..iterations, test_value, fn _, acc ->
      acc |> Monad.bind(fn x -> SpecificMonad.new(  # Use constructor like Maybe.just(, Either.right(, etc.x + 1) end)
    end)
  end
  
  # Direct version  
  direct_fun = fn ->
    Enum.reduce(1..iterations, test_value, fn _, acc ->
      acc |> Maybe.bind(fn x -> Maybe.just(x + 1) end)
    end)
  end
  
  {protocol_time, _} = :timer.tc(protocol_fun)
  {direct_time, _} = :timer.tc(direct_fun)
  
  overhead_percent = (protocol_time / direct_time - 1) * 100
  IO.puts("Protocol overhead: #{overhead_percent}%")
end
```

Use protocols when:

- **Genericity is valuable**: Function works with multiple monad types
- **Performance is acceptable**: Not in critical hot paths  
- **Code reuse matters**: Avoiding duplication across monad types

Use direct module calls when:

- **Performance is critical**: Hot paths or tight loops
- **Single monad type**: Only working with one specific monad
- **Simple operations**: Basic transformations that don't benefit from genericity

## Anti-Patterns

Avoid these common mistakes when working with the Monad protocol:

- **Mixing protocol and module calls** in the same generic function
- **Using specific constructors** like `Maybe.just/1` in protocol-based code  
- **Ignoring monad laws** when implementing custom monads
- **Overusing protocol** when direct module calls would be more efficient
- **Nested bind calls** instead of chaining with pipe operator
- **Not testing law compliance** for custom monad implementations

## When to Use

Use the Monad protocol when you want to:

- Write generic functions that work with multiple monad types
- Create reusable algorithms independent of specific monad implementation  
- Build libraries that support various monadic computations
- Ensure your code follows mathematical monad laws
- Enable composition patterns that work across different contexts
- Abstract over computational patterns (error handling, optional values, etc.)

## Built-in Behavior

- **Protocol dispatch**: Runtime type-based method selection
- **Law enforcement**: Implementations should satisfy monad laws
- **Composition support**: Operations designed for chaining and nesting
- **Type flexibility**: Works with any type implementing the protocol

## Summary

`Funx.Monad` provides the essential protocol for monadic programming in Elixir. It enables writing generic, reusable functions that work with any monadic type while preserving the mathematical properties that make monads reliable and composable.

The protocol supports three core operations - `bind`, `return`, and `join` - that together provide a foundation for functional composition patterns. When combined with other Funx modules like Utils, Predicate, and Eq, it enables powerful functional programming abstractions.

**Key Points**:

- **Generic programming**: Write functions that work with any monad
- **Mathematical foundation**: Based on category theory laws for reliability  
- **Composition patterns**: Chain computations while preserving context
- **Cross-module integration**: Combines with other Funx utilities
- **Performance trade-offs**: Consider overhead vs. genericity benefits
- **Law compliance**: Always verify implementations satisfy monad laws

**Canon**: Use for generic monadic algorithms, test law compliance, prefer direct modules for performance-critical code.
