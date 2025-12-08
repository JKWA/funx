# `Funx.Monad.Identity` Usage Rules

## LLM Guidance

### Functional Programming Foundation

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Identity**: The simplest possible monad - a transparent wrapper

- `identity(value)` - wraps any value with no additional behavior
- **No side effects**: Unlike Maybe (absence) or Either (errors)
- **Transparent operations**: All operations work directly on the wrapped value
- **Foundation monad**: Used for learning, testing, and building other monads
- **Laws satisfied trivially**: All monad laws hold automatically

### When to Use Identity

**✅ Use Identity for:**

- **Testing monadic code**: Simplest monad for unit tests
- **Learning FP concepts**: Understand map/bind/ap without side effects
- **Polymorphic functions**: Code that works with any monad
- **Prototyping**: Placeholder before choosing real monad

**❌ Don't use Identity for:**

- **Production business logic**: Usually need Maybe/Either semantics
- **Error handling**: Identity has no failure concept
- **Optional values**: Identity wraps everything, no absence

### Context Clues

**User language → Identity patterns:**

- "simplest monad" → Identity is the canonical minimal monad
- "test my monad code" → Use Identity for predictable testing
- "works with any monad" → Write polymorphic code using Identity for examples
- "learning functional programming" → Start with Identity to understand concepts

## Quick Reference

- Use `identity(value)` to wrap any value transparently
- All operations work directly on the wrapped value with no special behavior
- `run_identity(wrapped_value)` to extract the value
- Import `Funx.Monad` for `map`, `bind`, `ap` operations
- Perfect for testing, learning, and polymorphic programming
- Satisfies all monad laws trivially due to its simplicity

## Overview

`Funx.Monad.Identity` is the simplest monad - a transparent wrapper with no additional behavior.

Use Identity for:
- Learning monadic operations without complexity
- Testing monadic code with predictable behavior
- Writing polymorphic functions that work with any monad
- Building and understanding more complex monads

**Key insight**: Identity is "just a wrapper" - it provides the monadic interface while doing absolutely nothing else. This makes it perfect for understanding what the interface itself provides.

## Constructor

### `identity/1` - Wrap Any Value

Creates an Identity monad containing a value:

```elixir
Identity.identity(42)              # Identity(42)
Identity.identity("hello")         # Identity("hello")
Identity.identity([1, 2, 3])       # Identity([1, 2, 3])
Identity.identity(%{key: :value})  # Identity(%{key: :value})
```

### `run_identity/1` - Extract the Value

Extracts the wrapped value from an Identity:

```elixir
Identity.identity(42) |> Identity.run_identity()     # 42
Identity.identity("hello") |> Identity.run_identity() # "hello"
```

## Core Operations

### `map/2` - Transform the Wrapped Value

Applies a function to the wrapped value:

```elixir
import Funx.Monad

Identity.identity(5)
|> map(fn x -> x * 2 end)    # Identity(10)

Identity.identity("hello")
|> map(&String.upcase/1)     # Identity("HELLO")

Identity.identity([1, 2, 3])
|> map(&Enum.sum/1)          # Identity(6)
```

**Identity map behavior:**

- Function is always applied (no short-circuiting like Maybe)
- Result is always wrapped in Identity
- No side effects or special cases

### `bind/2` - Chain Identity Operations

Chains operations that return Identity values:

```elixir
import Funx.Monad

# Functions that return Identity
double_wrapped = fn x -> Identity.identity(x * 2) end
stringify_wrapped = fn x -> Identity.identity(to_string(x)) end
upcase_wrapped = fn s -> Identity.identity(String.upcase(s)) end

Identity.identity(5)
|> bind(double_wrapped)        # Identity(10)
|> bind(stringify_wrapped)     # Identity("10")
|> bind(upcase_wrapped)        # Identity("10")
```

**Identity bind behavior:**

- Always applies the function (no conditional logic)
- Automatically flattens nested Identity values
- Perfect for demonstrating monadic composition

### `ap/2` - Apply Functions Across Identity Values

Applies a wrapped function to a wrapped value:

```elixir
import Funx.Monad

# Function wrapped in Identity
Identity.identity(fn x -> x + 10 end)
|> ap(Identity.identity(5))          # Identity(15)

# Multiple arguments with curried function
add = fn x -> fn y -> x + y end end

Identity.identity(add)
|> ap(Identity.identity(3))          # Identity(fn y -> 3 + y end)
|> ap(Identity.identity(4))          # Identity(7)

# String concatenation
concat = fn x -> fn y -> x <> y end end

Identity.identity(concat)
|> ap(Identity.identity("Hello, "))
|> ap(Identity.identity("World!"))   # Identity("Hello, World!")
```

**Identity ap behavior:**

- Always applies function to value (no failure cases)
- Demonstrates applicative functor pattern clearly

### `tap/2` - Side Effects Without Changing Values

Executes a side-effect function on the wrapped value and returns the original Identity unchanged:

```elixir
import Funx.Monad.Identity

# Side effect on wrapped value
Identity.pure(42)
|> Tappable.tap(&IO.inspect(&1, label: "value"))  # Prints "value: 42"
# Returns: Identity(42)

# In a pipeline
Identity.pure(5)
|> map(&(&1 * 2))
|> Tappable.tap(&IO.inspect(&1, label: "doubled"))  # Prints "doubled: 10"
|> map(&(&1 + 1))
# Returns: Identity(11)
```

**Use `tap` when:**

- Debugging Identity pipelines - inspect values without breaking the chain
- Logging transformations in generic monadic code
- Side effects in monad-polymorphic functions
- Learning/teaching - observe values flowing through Identity

**Common tap patterns:**

```elixir
# Debug generic monad code
defmodule GenericProcessor do
  def process(monad) do  # Works with Identity, Maybe, Either, etc.
    monad
    |> map(&transform/1)
    |> tap(&IO.inspect(&1, label: "after transform"))  # Generic debugging
    |> bind(&validate/1)
  end
end

# Logging in Identity-based computation
Identity.pure(data)
|> Tappable.tap(fn d -> Logger.info("Processing: #{inspect(d)}") end)
|> map(&expensive_computation/1)
```

**Important notes:**

- The function's return value is discarded
- Always executes (Identity has no failure case)
- Less commonly needed than tap on Maybe/Either/Effect (Identity is usually for teaching/testing)
- Useful in monad-polymorphic code that works with any monad type
- Perfect for learning function application in context

## Testing with Identity

### Unit Testing Monad Laws

```elixir
defmodule IdentityLawsTest do
  use ExUnit.Case
  import Funx.Monad
  
  test "left identity law" do
    value = 42
    f = fn x -> Identity.identity(x * 2) end
    
    # Left identity: pure(x) |> bind(f) == f.(x)
    # Wrapping a value then binding should equal direct application
    left = bind(Identity.identity(value), f)
    right = f.(value)
    
    assert left == right
  end
  
  test "right identity law" do
    m = Identity.identity(42)
    
    # Right identity: m |> bind(pure) == m
    # Binding with pure should leave the monad unchanged
    result = bind(m, &Identity.identity/1)
    
    assert result == m
  end
  
  test "associativity law" do
    m = Identity.identity(42)
    f = fn x -> Identity.identity(x * 2) end
    g = fn x -> Identity.identity(x + 10) end
    
    # Associativity: (m |> bind(f)) |> bind(g) == m |> bind(fn x -> bind(f.(x), g) end)
    # Order of binding operations doesn't matter
    left = bind(bind(m, f), g)
    right = bind(m, fn x -> bind(f.(x), g) end)
    
    assert left == right
  end
  
  test "functor laws" do
    m = Identity.identity(42)
    f = fn x -> x * 2 end
    g = fn x -> x + 10 end
    
    # map(id, m) == m
    assert map(m, &Function.identity/1) == m
    
    # map(f . g, m) == map(f, map(g, m))
    composed = fn x -> f.(g.(x)) end
    assert map(m, composed) == map(map(m, g), f)
  end
end
```

### Testing Polymorphic Functions

```elixir
defmodule PolymorphicTest do
  use ExUnit.Case
  import Funx.Monad
  
  # A function that works with any monad
  def process_data(monad_value) do
    monad_value
    |> map(&to_string/1)
    |> bind(fn s -> 
      if String.length(s) > 3 do
        # Return appropriate monad type
        case monad_value do
          %Identity{} -> Identity.identity(String.upcase(s))
          %Maybe{} -> Maybe.just(String.upcase(s))
          %Either{} -> Either.right(String.upcase(s))
        end
      else
        case monad_value do
          %Identity{} -> Identity.identity("TOO SHORT")
          %Maybe{} -> Maybe.nothing()
          %Either{} -> Either.left("String too short")
        end
      end
    end)
  end
  
  test "polymorphic function with Identity" do
    # Test with long string
    result = process_data(Identity.identity(12345))
    assert result == Identity.identity("12345")
    
    # Test with short string  
    result = process_data(Identity.identity(42))
    assert result == Identity.identity("TOO SHORT")
  end
end
```

## Polymorphic Programming

Identity is perfect for learning and testing polymorphic monad code:

```elixir
# Generic function that works with any monad
def transform_and_chain(monad_value) do
  monad_value
  |> Monad.map(&(&1 + 5))              # Add 5
  |> Monad.bind(fn x -> 
    case monad_value do                  # Return appropriate type
      %Identity{} -> Identity.identity(x * 2)
      %Maybe{} -> Maybe.just(x * 2)
      %Either{} -> Either.right(x * 2)
    end
  end)
end

# Test with Identity - predictable, simple behavior
Identity.identity(10)
|> transform_and_chain()  # Identity(30)

# Same function works with other monads
Maybe.just(10)
|> transform_and_chain()  # Just(30)
```

### Custom Monad Implementation Example

```elixir
# Identity shows how to implement monads from scratch
defmodule CustomMonad do
  defstruct [:value]
  
  # Note: pure/1 is the convention used in Haskell/FP literature
  # It maps to identity/1 in this codebase
  def pure(value), do: %CustomMonad{value: value}
  
  defimpl Funx.Monad do
    def map(%CustomMonad{value: v}, f), do: CustomMonad.pure(f.(v))
    
    def bind(%CustomMonad{value: v}, f), do: f.(v)
    
    def ap(%CustomMonad{value: f}, %CustomMonad{value: v}) do
      CustomMonad.pure(f.(v))
    end
  end
end

# This custom monad behaves exactly like Identity
CustomMonad.pure(42)
|> Monad.map(&(&1 * 2))  # %CustomMonad{value: 84}
```

## Performance Characteristics

### Minimal Overhead

```elixir
# Identity has almost no runtime overhead
# It's essentially a tagged tuple with one element

defmodule PerformanceTest do
  def identity_operations(n) do
    # These operations are very fast
    1..n
    |> Enum.reduce(Identity.identity(0), fn i, acc ->
      acc
      |> Monad.map(&(&1 + i))
      |> Monad.bind(fn x -> Identity.identity(x * 2) end)
      |> Monad.map(&rem(&1, 1000))
    end)
  end
  
  def plain_operations(n) do
    # Compare with plain operations
    1..n
    |> Enum.reduce(0, fn i, acc ->
      (acc + i)
      |> (&(&1 * 2)).()
      |> rem(1000)
    end)
  end
end

# The Identity version will be only slightly slower than plain operations
# due to the minimal wrapping/unwrapping overhead
```

### Memory Usage

```elixir
# Identity uses minimal memory - just a wrapper struct
identity_value = Identity.identity("Hello, World!")

# Memory layout is approximately:
# %Identity{value: "Hello, World!"}
# Just the string plus a small struct wrapper

# Compare with other monads:
maybe_value = Maybe.just("Hello, World!")     # Similar overhead
either_value = Either.right("Hello, World!")  # Similar overhead
```

## String Representation

Identity implements String.Chars for easy IEx interaction:

```elixir
Identity.identity(42) |> to_string()     # "Identity(42)"
Identity.identity("hello") |> to_string() # "Identity(\"hello\")"
```

## Learning Patterns

### Understanding Monad Interface

```elixir
defmodule MonadTutorial do
  import Funx.Monad
  
  # Identity helps understand what each operation does
  def demonstrate_map() do
    # map transforms the value inside
    result = Identity.identity(5)
    |> map(fn x -> x * x end)
    
    IO.puts("map: Identity(5) -> Identity(25)")
    result  # Identity(25)
  end
  
  def demonstrate_bind() do
    # bind chains operations that return wrapped values
    double_it = fn x -> Identity.identity(x * 2) end
    
    result = Identity.identity(5)
    |> bind(double_it)
    
    IO.puts("bind: Identity(5) -> Identity(10)")  
    result  # Identity(10)
  end
  
  def demonstrate_ap() do
    # ap applies wrapped functions to wrapped values
    add_fn = fn x -> fn y -> x + y end end
    
    result = Identity.identity(add_fn)
    |> ap(Identity.identity(3))
    |> ap(Identity.identity(7))
    
    IO.puts("ap: Identity(add) + Identity(3) + Identity(7) -> Identity(10)")
    result  # Identity(10)
  end
  
  def show_difference_from_maybe() do
    # Same operations with Maybe show the difference
    transform = fn x -> x * 2 end
    
    # Identity always transforms
    identity_result = Identity.identity(5) |> map(transform)
    # Identity(10)
    
    # Maybe might not transform (if Nothing)
    maybe_result1 = Maybe.just(5) |> map(transform)      # Maybe.just(10) 
    maybe_result2 = Maybe.nothing() |> map(transform)    # Maybe.nothing()
    
    # Identity is predictable, Maybe depends on presence
  end
end
```

Identity helps you understand monadic patterns without complexity:

```elixir
# Pattern recognition: Transform -> Validate -> Chain
def learn_pattern(value) do
  Identity.identity(value)
  |> map(&(&1 + 10))           # Transform: add 10
  |> bind(fn x ->              # Validate and chain
    if x > 15 do
      Identity.identity("large: #{x}")
    else
      Identity.identity("small: #{x}")
    end
  end)
end

learn_pattern(10)  # Identity("large: 20")
learn_pattern(3)   # Identity("small: 13")
```

## Integration with Utils

```elixir
# Identity works seamlessly with Utils functions
add_ten = Funx.Utils.curry_r(&+/2).(10)

Identity.identity(5)
|> Monad.map(add_ten)        # Identity(15)

# Function composition in monadic context  
identity_pipeline = fn value ->
  Identity.identity(value)
  |> Monad.map(&(&1 + 1))    # Add 1
  |> Monad.map(&(&1 * 2))    # Multiply by 2  
  |> Monad.map(&(&1 - 3))    # Subtract 3
end

identity_pipeline.(5)        # Identity(9)
```

### Testing Other Monads

```elixir
defmodule MonadTester do
  import Funx.Monad
  
  # Test the same logic across different monads
  def test_computation(monad_constructor, value) do
    computation = fn m ->
      m
      |> map(&(&1 * 2))
      |> bind(fn x ->
        monad_constructor.(x + 5)
      end)
      |> map(&to_string/1)
    end
    
    monad_constructor.(value)
    |> computation.()
  end
  
  def run_tests() do
    # Test with Identity - always succeeds predictably
    identity_result = test_computation(&Identity.identity/1, 10)
    # Identity("25")
    
    # Test with Maybe - succeeds with just
    maybe_result = test_computation(&Maybe.just/1, 10) 
    # Maybe.just("25")
    
    # Test with Either - succeeds with right
    either_result = test_computation(&Either.right/1, 10)
    # Either.right("25")
    
    # Identity gives us the baseline expected behavior
    %{
      identity: identity_result,
      maybe: maybe_result, 
      either: either_result
    }
  end
end
```

## Advanced Patterns

### Custom Monad Implementation Guide

```elixir
# Identity shows the minimal implementation needed for a monad

defmodule CustomMonad do
  defstruct [:value]
  
  # Constructor (like Identity.identity/1)
  def pure(value), do: %__MODULE__{value: value}
  
  # Functor implementation (like map)
  def fmap(%__MODULE__{value: v}, f) do
    %__MODULE__{value: f.(v)}
  end
  
  # Monad implementation (like bind)
  def bind(%__MODULE__{value: v}, f) do
    f.(v)  # f should return another CustomMonad
  end
  
  # Extractor (like run_identity)
  def extract(%__MODULE__{value: v}), do: v
end

# This follows the same pattern as Identity but could add behavior
# For example, logging, counting operations, etc.

defimpl Funx.Monad, for: CustomMonad do
  def map(monad, f), do: CustomMonad.fmap(monad, f)
  def bind(monad, f), do: CustomMonad.bind(monad, f)
  def ap(monad_f, monad_x) do
    # Standard applicative implementation
    CustomMonad.bind(monad_f, fn f ->
      CustomMonad.fmap(monad_x, f)
    end)
  end
end
```

### Monad Stack Exploration

```elixir
# Identity at the bottom of monad transformer stacks

# MaybeT Identity a ≅ Maybe a
# EitherT e Identity a ≅ Either e a  
# StateT s Identity a ≅ State s a

# Identity is often the "base" monad in transformer stacks
# Understanding Identity helps understand how transformers work

defmodule StackExample do
  # Simulate MaybeT Identity (which is just Maybe)
  def maybe_t_identity_example(value) do
    # This is conceptually MaybeT Identity, but it's just Maybe
    case value do
      nil -> Maybe.nothing()
      x when x > 0 -> Maybe.just(x * 2)
      _ -> Maybe.nothing()
    end
  end
  
  # If we had a real MaybeT Identity, it would look like:
  # newtype MaybeT Identity a = Identity (Maybe a)
  # But since Identity is transparent, it's just Maybe a
end
```

## Common Patterns and Use Cases

### Educational Sequencing

```elixir
# Use Identity to learn sequence/traverse patterns
defmodule SequenceExample do
  import Funx.Monad
  
  def sequence_identities(list_of_identities) do
    # This is educational - sequence([Identity a]) -> Identity [a]
    values = list_of_identities |> Enum.map(&Identity.run_identity/1)
    Identity.identity(values)
  end
  
  def traverse_with_identity(list, f) do
    # Apply f to each element, collect in Identity
    results = list |> Enum.map(f) |> Enum.map(&Identity.run_identity/1)
    Identity.identity(results)
  end
  
  # Examples
  def examples() do
    identities = [Identity.identity(1), Identity.identity(2), Identity.identity(3)]
    sequenced = sequence_identities(identities)
    # Identity([1, 2, 3])
    
    numbers = [1, 2, 3]
    traversed = traverse_with_identity(numbers, fn x -> Identity.identity(x * 2) end)
    # Identity([2, 4, 6])
  end
end
```

### Debugging Monad Chains

```elixir
# Identity for debugging complex monad chains
defmodule DebugMonad do
  import Funx.Monad
  
  def debug_chain(value) do
    # Use Identity to debug logic without side effects
    Identity.identity(value)
    |> map(fn x -> 
      IO.puts("Step 1: #{x}")
      x * 2
    end)
    |> bind(fn x ->
      IO.puts("Step 2: #{x}")
      Identity.identity(x + 10)
    end)
    |> map(fn x ->
      IO.puts("Step 3: #{x}")
      to_string(x)
    end)
  end
  
  # Once logic is correct, switch to real monad
  def production_chain(value) do
    Maybe.just(value)  # or Either.right(value)
    |> map(fn x -> x * 2 end)
    |> bind(fn x -> 
      if x > 0 do
        Maybe.just(x + 10)
      else
        Maybe.nothing()
      end
    end)
    |> map(&to_string/1)
  end
end
```

## Summary

Identity provides the foundation for understanding monadic programming:

**Core Operations:**

- `identity/1`: Wrap any value transparently
- `run_identity/1`: Extract the wrapped value
- `map/2`: Transform wrapped values with no side effects
- `bind/2`: Chain Identity-returning operations with automatic flattening
- `ap/2`: Apply wrapped functions to wrapped values

**Key Uses:**

- **Learning**: Understand monad interface without complexity
- **Testing**: Predictable behavior for unit tests
- **Polymorphism**: Write generic code that works with any monad
- **Prototyping**: Placeholder before choosing real monad
- **Debugging**: Validate monad chain logic

**Mathematical Properties:**

- **Functor**: `map` applies function directly to wrapped value
- **Applicative**: `ap` applies function with no failure cases
- **Monad**: `bind` chains operations with trivial flattening
- **Laws**: All monad laws satisfied automatically due to simplicity

Remember: Identity is "just a wrapper" - it provides the monadic interface while being completely transparent. This makes it perfect for learning what monads are and testing monadic code without the complexity of real-world side effects.
