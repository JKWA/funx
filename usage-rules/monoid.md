# `Funx.Monoid` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monoid operations are under `Funx.Monoid` protocol

- **NO separate Semigroup protocol** - Elixir protocols cannot be extended after definition  
- Always use `Monoid.empty/1`, `Monoid.append/2` or import `Funx.Monoid`
- Different from Haskell's separate Semigroup and Monoid typeclasses

**Monoid Protocol**: Mathematical structure for associative combination with identity

- `empty/1`: Returns the identity element for the monoid (like 0 for addition, [] for lists)
- `append/2`: Associative binary operation that combines two values
- `wrap/2` / `unwrap/1`: Infrastructure functions to convert between raw values and monoid wrappers
- Example: `Monoid.append(%Sum{}, 5, 3)` combines numbers using addition

**Monoid Laws**: Mathematical guarantees that ensure predictable behavior  

- **Left Identity**: `append(empty(m), x) === x`
- **Right Identity**: `append(x, empty(m)) === x`  
- **Associativity**: `append(append(a, b), c) === append(a, append(b, c))`
- These laws enable safe composition and parallel computation
- Example: Summing `[1,2,3,4]` can be computed as `(1+2)+(3+4)` or `1+(2+(3+4))`

**Algebraic Data Combination**: Monoids represent ways to combine data

- **Sum**: Numbers with addition (`0` identity, `+` operation)  
- **Product**: Numbers with multiplication (`1` identity, `*` operation)
- **Max/Min**: Numbers with comparison (`-∞/+∞` identity, `max/min` operation)
- **List**: Collections with concatenation (`[]` identity, `++` operation)
- **All/Any**: Booleans with AND/OR (`true/false` identity, `&&/||` operation)
- Example: Combining user preferences uses monoid to merge settings

**Higher-Level Abstractions**: Monoids power utility functions

- `Math.sum/1`, `Math.product/1` use numeric monoids internally
- `Eq.concat_all/1` uses All monoid for AND-ing equality checks
- `Predicate.p_all/1` uses All monoid for combining boolean predicates  
- Example: `Math.sum([1,2,3])` internally uses Sum monoid but hides the complexity

## LLM Decision Guide: When to Use Monoid Protocol

**✅ Use Monoid Protocol when:**

- Need associative combination with identity (merging, accumulating, folding)
- Building reusable combination logic for custom data types
- Want parallel/distributed computation guarantees  
- Creating utility functions that combine multiple values
- User says: "combine", "merge", "accumulate", "fold", "reduce"

**❌ Don't use Monoid Protocol when:**

- Simple one-off combinations (use direct operations like `+`, `++`)
- Non-associative operations (like subtraction or division)
- No meaningful identity element exists
- Operations have side effects or are non-deterministic

**⚡ Monoid Strategy Decision:**

- **Built-in types**: Use existing monoids (Sum, Product, Max, Min, ListConcat)
- **Custom combination**: Define new monoid struct and protocol implementation  
- **Application code**: Use high-level utilities (`Math`, `Eq`, `Ord`)
- **Library code**: Expose monoids through utility functions, not raw protocol

**⚙️ Function Choice Guide (Mathematical Purpose):**

- **Identity element**: `empty/1` to get neutral value for combination
- **Binary combination**: `append/2` to combine two values associatively
- **Multiple combination**: `m_concat/2` to combine a list of values
- **Utility helpers**: `m_append/3` for low-level monoid operations

## LLM Context Clues

**User language → Monoid patterns:**

- "combine all these values" → Use `m_concat/2` or utility functions
- "merge with defaults" → Use monoid with appropriate identity element
- "accumulate results" → Use monoid for associative accumulation  
- "parallel computation" → Monoids enable safe parallelization
- "sum/product/max/min" → Use `Math` utilities backed by monoids
- "AND/OR logic" → Use `All/Any` monoids for boolean combination

## Quick Reference

- A monoid = `empty/1` (identity) + `append/2` (associative).  
- Identities must be true identities (e.g. `0` for sum, `1` for product, `[]` for concatenation).  
- `wrap/2` and `unwrap/1` exist for infrastructure, not daily use.  
- `m_append/3` and `m_concat/2` are low-level helpers that power higher abstractions.  
- Application code should prefer helpers in `Math`, `Eq`, `Ord`, or `Predicate`.

## Overview

`Funx.Monoid` defines how values combine under an associative operation with an identity.  
Each monoid is represented by a struct (e.g. `%Sum{}`, `%Product{}`, `%Eq.All{}`, `%Ord{}`) and implements:

- `Monoid.empty/1` → the identity element  
- `Monoid.append/2` → associative combination  
- `wrap/2` / `unwrap/1` → convert between raw values and monoid structs  

**Important Implementation Detail**: Unlike Haskell's separate Semigroup and Monoid typeclasses, Elixir's protocol system limitations require all operations under the single `Funx.Monoid` protocol.

Monoids are rarely used directly in application code. Instead, they support utilities like `Math.sum/1`, `Eq.concat_all/1`, and `Ord.concat/1`.

## Protocol Rules

- Provide all four functions: `empty/1`, `append/2`, `wrap/2`, `unwrap/1`.  
- Identity: `append(empty(m), x) == x == append(x, empty(m))`.  
- Associativity: `append(append(a, b), c) == append(a, append(b, c))`.  
- Purity: results must be deterministic and side-effect free.

**Note**: While not typically needed, you can define a `join/1` operation for monoids that flattens nested monoid values (e.g., combining lists of lists) using `m_concat/2`. This provides symmetry with Monad operations for flattening nested structures.  

## Preferred Usage

### Go Through Utilities

Use high-level helpers instead of wiring monoids manually:

- **Numbers** → `Math.sum/1`, `Math.product/1`, `Math.max/1`, `Math.min/1`  
- **Equality** → `Eq.concat_all/1`, `Eq.concat_any/1`  
- **Ordering** → `Ord.concat/1`, `Ord.append/2`  
- **Predicates** → `Predicate.p_and/2`, `Predicate.p_or/2`, `Predicate.p_all/1`, `Predicate.p_any/1`

These functions already call `m_concat/2` and `m_append/3`.  
You don't need to construct `%Monoid.*{}` by hand.

### Examples

#### Equality Composition

```elixir
alias Funx.Eq, as: EqU

name_eq = EqU.contramap(& &1.name)
age_eq  = EqU.contramap(& &1.age)

EqU.concat_all([name_eq, age_eq])  # AND semantics
EqU.concat_any([name_eq, age_eq])  # OR semantics
```

#### Ordering Composition

```elixir
alias Funx.Ord, as: OrdU

age  = OrdU.contramap(& &1.age)
name = OrdU.contramap(& &1.name)

OrdU.concat([age, name])  # lexicographic ordering
```

#### Math Helpers

```elixir
alias Funx.Math

Math.sum([1, 2, 3])     # => 6
Math.product([2, 3, 4]) # => 24
Math.max([7, 3, 5])     # => 7
Math.min([7, 3, 5])     # => 3
```

## Interop

- `Eq` relies on `Eq.All` and `Eq.Any` monoids for composition.
- `Ord` uses the `Ord` monoid for lexicographic comparison.
- `Math` uses monoids for numeric folds.

**Rule of thumb:** application code never wires `%Monoid.*{}` directly—always go through the utility combinators.

## Stability Contract

- Identities must be stable and input-independent.
- `append/2` must be associative for all valid values.
- `wrap/2` and `unwrap/1` must be inverses.

## Anti-Patterns

- Hand-wiring `%Monoid.*{}` in application code.
- Mixing different monoid types in one `append/2`.
- Using fake identities (`nil` instead of `0` for sum).
- Hiding side effects inside protocol functions.

**Type Safety Warning**: Always ensure values passed to `append/2` are of the same wrapped monoid type:

```elixir
# ❌ Wrong - mixing types
append(%Sum{}, 1, %Product{value: 2})  # Invalid - type mismatch

# ✅ Right - consistent types  
append(%Sum{}, 1, 2)                   # OK: both values are integers
```

## Good Patterns

- Use `Math`, `Eq`, `Ord`, or `Predicate` instead of raw monoids.
- Keep identities explicit in library code (`0`, `1`, `[]`, `Float.min_finite()` / `Float.max_finite()`).
- Let `m_concat/2` and `m_append/3` handle the wrapping/combining logic.

## When to Define a New Monoid

Define a monoid struct if you need associative combination + identity:

- Counters, tallies, or scores
- Config merges (e.g. left-biased / right-biased maps)
- "Best-of" or "min-by/max-by" selections
- Predicate or decision combination

Expose it through a utility module—application code should not use it raw.

## Built-in Instances

- `%Funx.Monoid.Sum{}` — numeric sum (`0`)
- `%Funx.Monoid.Product{}` — numeric product (`1`)
- `%Funx.Monoid.Max{}` — maximum (`Float.min_finite()`)
- `%Funx.Monoid.Min{}` — minimum (`Float.max_finite()`)
- `%Funx.Monoid.ListConcat{}` — list concatenation (`[]`)
- `%Funx.Monoid.StringConcat{}` — string concatenation (`""`)
- `%Funx.Monoid.Predicate.All{}` — predicate AND composition (identity: `fn _ -> true end`)
- `%Funx.Monoid.Predicate.Any{}` — predicate OR composition (identity: `fn _ -> false end`)
- `%Funx.Monoid.Eq.All{}` / `%Funx.Monoid.Eq.Any{}` — equality composition
- `%Funx.Monoid.Ord{}` — ordering composition

These back the higher-level helpers. Use `Math`, `Eq`, `Ord`, or `Predicate` instead.

## LLM Code Templates

### Basic Monoid Usage Template

```elixir
defmodule DataAggregator do
  import Funx.Monoid
  alias Funx.Math
  
  # Use high-level utilities instead of raw monoids
  def analyze_numbers(numbers) do
    %{
      sum: Math.sum(numbers),           # Uses Sum monoid internally
      product: Math.product(numbers),   # Uses Product monoid internally  
      maximum: Math.max(numbers),       # Uses Max monoid internally
      minimum: Math.min(numbers)        # Uses Min monoid internally
    }
  end
  
  # Custom combination using monoid utilities
  def combine_stats(stat_list) do
    stat_list
    |> Enum.map(&extract_numbers/1)
    |> Enum.reduce(fn nums1, nums2 ->
      %{
        sum: Math.sum([nums1.sum, nums2.sum]),
        product: Math.product([nums1.product, nums2.product]),
        max: Math.max([nums1.max, nums2.max]),
        min: Math.min([nums1.min, nums2.min])
      }
    end)
  end
end
```

### Custom Monoid Implementation Template

```elixir
defmodule UserPreferences do
  defstruct theme: :light, notifications: true, language: "en"
end

# Custom monoid for merging user preferences (right-biased)
defmodule Funx.Monoid.UserPreferences do
  defstruct []
  
  defimpl Funx.Monoid do
    def empty(_), do: %UserPreferences{}
    
    def append(_, prefs1, prefs2) do
      # Right-biased merge: prefs2 overwrites prefs1 for non-nil values
      %UserPreferences{
        theme: prefs2.theme || prefs1.theme,
        notifications: if(is_nil(prefs2.notifications), do: prefs1.notifications, else: prefs2.notifications),
        language: prefs2.language || prefs1.language
      }
    end
    
    def wrap(_, prefs), do: prefs
    def unwrap(prefs), do: prefs
  end
end

defmodule PreferencesManager do
  alias Funx.Monoid.Utils, as: MU
  
  def merge_user_preferences(preference_list) do
    # Use monoid to combine multiple preference objects
    MU.m_concat(%Funx.Monoid.UserPreferences{}, preference_list)
  end
  
  def merge_with_defaults(user_prefs, defaults) do
    # Combine with defaults using monoid
    MU.m_append(%Funx.Monoid.UserPreferences{}, defaults, user_prefs)
  end
end
```

### Monoid Law Verification Template

```elixir
defmodule MonoidLawTester do
  import Funx.Monoid
  
  # Generic test for any monoid implementation
  def verify_monoid_laws(monoid_module, test_values) do
    [a, b, c] = test_values
    m = struct(monoid_module)
    
    # Left Identity: empty + a = a
    left_identity = append(m, empty(m), a) == a
    
    # Right Identity: a + empty = a  
    right_identity = append(m, a, empty(m)) == a
    
    # Associativity: (a + b) + c = a + (b + c)
    left_assoc = append(m, append(m, a, b), c)
    right_assoc = append(m, a, append(m, b, c))
    associativity = left_assoc == right_assoc
    
    %{
      left_identity: left_identity,
      right_identity: right_identity,
      associativity: associativity,
      all_laws_hold: left_identity && right_identity && associativity
    }
  end
  
  # Test built-in monoids
  def test_built_in_monoids() do
    # Test Sum monoid
    sum_result = verify_monoid_laws(Funx.Monoid.Sum, [5, 3, 8])
    IO.inspect(sum_result, label: "Sum monoid laws")
    
    # Test Product monoid  
    product_result = verify_monoid_laws(Funx.Monoid.Product, [2, 3, 4])
    IO.inspect(product_result, label: "Product monoid laws")
    
    # Test List concatenation
    list_result = verify_monoid_laws(Funx.Monoid.ListConcat, [[1, 2], [3], [4, 5]])
    IO.inspect(list_result, label: "ListConcat monoid laws")
  end
end
```

### Parallel Computation with Monoids Template

```elixir
defmodule ParallelProcessor do
  alias Funx.Math
  
  # Monoids enable safe parallel computation due to associativity
  def parallel_sum(large_list) do
    large_list
    |> Enum.chunk_every(1000)  # Split into chunks
    |> Task.async_stream(&Math.sum/1, max_concurrency: System.schedulers())
    |> Enum.map(fn {:ok, partial_sum} -> partial_sum end)
    |> Math.sum()  # Combine partial results
  end
  
  def parallel_statistics(data_chunks) do
    # Process chunks in parallel, then combine results
    stats = data_chunks
    |> Task.async_stream(fn chunk ->
      %{
        count: length(chunk),
        sum: Math.sum(chunk),
        max: Math.max(chunk),
        min: Math.min(chunk)
      }
    end, max_concurrency: System.schedulers())
    |> Enum.map(fn {:ok, stat} -> stat end)
    
    # Combine partial statistics using monoid properties
    %{
      total_count: Math.sum(Enum.map(stats, & &1.count)),
      total_sum: Math.sum(Enum.map(stats, & &1.sum)),
      overall_max: Math.max(Enum.map(stats, & &1.max)),
      overall_min: Math.min(Enum.map(stats, & &1.min))
    }
  end
end
```

### Utils Integration Template

```elixir
defmodule MonoidWithUtils do
  alias Funx.Utils
  alias Funx.Math
  
  # Create curried monoid operations
  def build_aggregators() do
    # Curry math operations for reuse
    sum_reducer = Utils.curry_r(&Math.sum/1)
    product_reducer = Utils.curry_r(&Math.product/1)
    max_finder = Utils.curry_r(&Math.max/1)
    
    # Create specialized aggregators
    sum_by = fn key ->
      fn data_list ->
        data_list
        |> Enum.map(&Map.get(&1, key))
        |> Math.sum()
      end
    end
    
    product_by = fn key ->
      fn data_list ->
        data_list
        |> Enum.map(&Map.get(&1, key))  
        |> Math.product()
      end
    end
    
    %{
      sum_reducer: sum_reducer,
      product_reducer: product_reducer,
      max_finder: max_finder,
      sum_by: sum_by,
      product_by: product_by
    }
  end
  
  def analyze_grouped_data(grouped_data) do
    aggregators = build_aggregators()
    
    # Apply different aggregations to different groups
    for {group, data} <- grouped_data do
      {group, %{
        total_score: aggregators.sum_by.(:score).(data),
        multiplied_weights: aggregators.product_by.(:weight).(data),
        count: length(data)
      }}
    end
  end
end
```

### Predicate Integration Template

```elixir
defmodule MonoidPredicateIntegration do
  alias Funx.Predicate
  alias Funx.Monoid.Utils, as: MU
  alias Funx.Monoid.Predicate.{All, Any}
  
  # Predicates use specific monoids internally for combination
  def build_complex_validators() do
    # Individual predicates  
    is_adult = fn person -> person.age >= 18 end
    has_email = fn person -> String.contains?(person.email, "@") end
    has_name = fn person -> String.length(person.name) > 0 end
    is_verified = fn person -> person.verified end
    
    # Combine using predicate utilities (which use Predicate.All/Any monoids internally)
    # p_all uses m_concat with %All{} monoid
    strict_validator = Predicate.p_all([is_adult, has_email, has_name, is_verified])
    basic_validator = Predicate.p_all([has_email, has_name])
    
    # p_any uses m_concat with %Any{} monoid  
    flexible_validator = Predicate.p_any([is_adult, is_verified])
    
    %{
      strict: strict_validator,
      basic: basic_validator,
      flexible: flexible_validator
    }
  end
  
  # Show how predicates compose via specific monoid types
  def demonstrate_predicate_monoid_connection() do
    # These predicates use Predicate.All/Any monoids internally
    predicate1 = fn x -> x > 0 end
    predicate2 = fn x -> x < 100 end  
    predicate3 = fn x -> rem(x, 2) == 0 end
    
    # p_all uses m_concat(%All{}, predicates) for AND combination
    all_validator = Predicate.p_all([predicate1, predicate2, predicate3])
    
    # p_any uses m_concat(%Any{}, predicates) for OR combination  
    any_validator = Predicate.p_any([predicate1, predicate2, predicate3])
    
    # You could also use monoids directly (though predicates are cleaner)
    manual_all = MU.m_concat(%All{}, [predicate1, predicate2, predicate3])
    manual_any = MU.m_concat(%Any{}, [predicate1, predicate2, predicate3])
    
    # Test values
    test_value = 42
    
    %{
      predicate_all: all_validator.(test_value),  # true (42 > 0 AND 42 < 100 AND even)
      predicate_any: any_validator.(test_value),  # true (42 > 0 OR 42 < 100 OR even)
      manual_all: manual_all.(test_value),        # Same result as predicate_all
      manual_any: manual_any.(test_value)         # Same result as predicate_any
    }
  end
  
  # Show the monoid identities that predicates rely on
  def demonstrate_predicate_monoid_laws() do
    import Funx.Monoid
    
    # All monoid: identity is function that always returns true
    all_identity = empty(%All{})
    IO.inspect(all_identity.(:anything), label: "All monoid identity")  # true
    
    # Any monoid: identity is function that always returns false  
    any_identity = empty(%Any{})
    IO.inspect(any_identity.(:anything), label: "Any monoid identity")  # false
    
    # This is why p_all([]) returns true and p_any([]) returns false
    empty_all = Predicate.p_all([])
    empty_any = Predicate.p_any([])
    
    %{
      empty_all_result: empty_all.(:test),  # true (All identity)
      empty_any_result: empty_any.(:test)   # false (Any identity)
    }
  end
end
```

## LLM Testing Guidance

### Test Monoid Laws

```elixir
defmodule MonoidTest do
  use ExUnit.Case
  import Funx.Monoid
  
  # Test that custom monoids satisfy laws
  test "UserPreferences monoid satisfies laws" do
    prefs1 = %UserPreferences{theme: :dark, language: "en"}
    prefs2 = %UserPreferences{notifications: false}
    prefs3 = %UserPreferences{theme: :light, language: "es"}
    
    monoid = %Funx.Monoid.UserPreferences{}
    
    # Test left identity: empty + a = a
    assert append(monoid, empty(monoid), prefs1) == prefs1
    
    # Test right identity: a + empty = a
    assert append(monoid, prefs1, empty(monoid)) == prefs1
    
    # Test associativity: (a + b) + c = a + (b + c)
    left_assoc = append(monoid, append(monoid, prefs1, prefs2), prefs3)
    right_assoc = append(monoid, prefs1, append(monoid, prefs2, prefs3))
    assert left_assoc == right_assoc
  end
  
  test "Math utilities use monoids correctly" do
    numbers = [1, 2, 3, 4, 5]
    
    # These should be equivalent to manual monoid operations
    assert Math.sum(numbers) == 15
    assert Math.product(numbers) == 120
    
    # Test empty list behavior (should return identity)
    assert Math.sum([]) == 0
    assert Math.product([]) == 1
  end
end
```

### Test Higher-Level Utilities

```elixir
test "utility functions hide monoid complexity" do
  # Test that utilities work without exposing monoid details
  data = [
    %{score: 10, weight: 0.5},
    %{score: 20, weight: 1.0},  
    %{score: 15, weight: 0.8}
  ]
  
  total_score = data |> Enum.map(& &1.score) |> Math.sum()
  assert total_score == 45
  
  total_weight = data |> Enum.map(& &1.weight) |> Math.sum()
  assert total_weight == 2.3
end
```

## LLM Debugging Tips

### Debug Monoid Operations

```elixir
def debug_monoid_combination(monoid, values) do
  IO.puts("Debugging monoid: #{inspect(monoid)}")
  IO.puts("Identity: #{inspect(empty(monoid))}")
  
  # Show step-by-step combination
  Enum.reduce(values, empty(monoid), fn value, acc ->
    result = append(monoid, acc, value)
    IO.puts("#{inspect(acc)} + #{inspect(value)} = #{inspect(result)}")
    result
  end)
end

# Usage:
# debug_monoid_combination(%Funx.Monoid.Sum{}, [1, 2, 3, 4])
```

### Verify Associativity for Parallel Computing

```elixir
def verify_parallel_safety(operation, data, chunk_size) do
  # Sequential computation
  sequential_result = operation.(data)
  
  # Parallel computation (different groupings)
  parallel_result1 = data
  |> Enum.chunk_every(chunk_size)
  |> Enum.map(operation)
  |> operation.()
  
  parallel_result2 = data
  |> Enum.chunk_every(chunk_size * 2)  # Different chunk size
  |> Enum.map(operation)
  |> operation.()
  
  %{
    sequential: sequential_result,
    parallel1: parallel_result1,
    parallel2: parallel_result2,
    results_match: sequential_result == parallel_result1 && 
                   parallel_result1 == parallel_result2
  }
end

# Test with Math.sum (which uses Sum monoid)
# verify_parallel_safety(&Math.sum/1, [1,2,3,4,5,6,7,8], 3)
```

## LLM Common Mistakes to Avoid

**❌ Don't use raw monoids in application code**

```elixir
# ❌ Wrong: manually constructing monoids
def sum_values(numbers) do
  sum_monoid = %Funx.Monoid.Sum{}
  Enum.reduce(numbers, Monoid.empty(sum_monoid), fn num, acc ->
    Monoid.append(sum_monoid, acc, num)
  end)
end

# ✅ Correct: use utility functions
def sum_values(numbers) do
  Math.sum(numbers)  # Much simpler and clearer
end
```

**❌ Don't ignore monoid laws**

```elixir
# ❌ Wrong: non-associative operation
defmodule BrokenMonoid do
  defstruct []
  
  defimpl Funx.Monoid do
    def empty(_), do: 0
    def append(_, a, b), do: a - b  # Subtraction is NOT associative!
    def wrap(_, x), do: x
    def unwrap(x), do: x
  end
end

# ✅ Correct: ensure associativity
defmodule CorrectMonoid do
  defstruct []
  
  defimpl Funx.Monoid do
    def empty(_), do: 0
    def append(_, a, b), do: a + b  # Addition IS associative
    def wrap(_, x), do: x
    def unwrap(x), do: x
  end
end
```

**❌ Don't use wrong identity elements**

```elixir
# ❌ Wrong: nil is not identity for addition
defmodule BadSumMonoid do  
  defstruct []
  
  defimpl Funx.Monoid do
    def empty(_), do: nil  # Wrong! nil + 5 != 5
    def append(_, a, b), do: (a || 0) + (b || 0)
    def wrap(_, x), do: x  
    def unwrap(x), do: x
  end
end

# ✅ Correct: 0 is the true identity for addition
defmodule GoodSumMonoid do
  defstruct []
  
  defimpl Funx.Monoid do
    def empty(_), do: 0  # Correct! 0 + x = x
    def append(_, a, b), do: a + b
    def wrap(_, x), do: x
    def unwrap(x), do: x
  end
end
```

## Summary

`Funx.Monoid` provides the mathematical foundation for associative combination with identity. Use it to:

- **Build reusable combination logic**: Define monoids for custom data types that need merging
- **Enable parallel computation**: Monoid laws guarantee safe parallelization and chunking
- **Power utility functions**: `Math`, `Eq`, `Ord`, and `Predicate` all use monoids internally
- **Compose complex operations**: Chain monoid operations for sophisticated data processing
- **Ensure mathematical correctness**: Monoid laws provide guarantees about behavior

**Key Implementation Detail**: Unlike Haskell's separate Semigroup and Monoid typeclasses, all operations are under the single `Funx.Monoid` protocol due to Elixir's protocol limitations.

**Best Practice**: Use high-level utilities (`Math.sum/1`, `Eq.concat_all/1`) instead of raw monoid operations. Define custom monoids for domain-specific combination needs, but expose them through utility modules rather than direct protocol usage.

Remember: Monoids are about **predictable combination**. If your operation is associative and has a true identity element, it's probably a monoid and can leverage all the mathematical guarantees and optimizations that come with that structure.
