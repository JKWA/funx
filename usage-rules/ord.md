# `Funx.Ord` Usage Rules

## Core Concepts

**Protocol + Custom Ord Pattern**: Use both together for maximum flexibility

- **Protocol implementation** = domain's default ordering (whatever makes business sense)
- **Custom Ord injection** = context-specific ordering when needed
- **Key insight**: Protocol provides sensible defaults, custom Ord provides flexibility

**Contramap**: Contravariant functor - transforms inputs before comparison

- `contramap(&String.length/1, Ord)` compares by string length only
- Mathematical dual of `map` - transforms "backwards" through the data flow  
- Key pattern: transform the input, not the comparison result

**Utils Pattern**: Inject custom Ord logic or default to protocol

- `Ord.compare(a, b, custom_ord)` - uses custom_ord
- `Ord.compare(a, b)` - uses protocol dispatch

**Monoid Composition**: Combine ordering logic lexicographically

- `append(ord1, ord2)` - combine two (ord1 then ord2)
- `concat([ord1, ord2, ord3])` - combine list (in sequence)

## Quick Patterns

```elixir
# STEP 1: Implement protocol for domain's default ordering
defimpl Funx.Ord, for: User do
  def lt?(%User{joined_at: a}, %User{joined_at: b}), do: Funx.Ord.lt?(a, b)
  def le?(a, b), do: lt?(a, b) or eq?(a, b)
  def gt?(a, b), do: not le?(a, b)  
  def ge?(a, b), do: not lt?(a, b)
end

# STEP 2: Use protocol directly for default ordering
Ord.lt?(user1, user2)  # Uses protocol (by joined_at)
List.sort(users)       # Uses protocol default

# STEP 3: Inject custom Ord for specific contexts
by_age = Ord.contramap(& &1.age)
Ord.compare(user1, user2, by_age)  # Compare by age instead
List.sort(users, by_age)                 # Sort by age, not joined_at

# Combine fields lexicographically
age_then_name = Ord.concat([
  Ord.contramap(& &1.age),
  Ord.contramap(& &1.name)
])

# Use with Funx.List
Funx.List.sort(users, by_age)
Funx.List.strict_sort(users, age_then_name)  # removes duplicates
```

## Key Rules

- **IMPLEMENT PROTOCOL** for domain's default ordering (whatever makes business sense)
- **USE CUSTOM ORD** when you need different ordering for specific operations
- **MUST implement all four** `lt?/2`, `le?/2`, `gt?/2`, `ge?/2` (no optional defaults)
- **Must define total order**: antisymmetric, transitive, connex
- Use `contramap/2` to transform inputs before comparison
- Use monoid functions for composition: `append/2`, `concat/1`  
- Pattern: Protocol for defaults, Utils injection for flexibility
- Keep `Ord` and `Eq` consistent: `compare(a,b) == :eq <=> Eq.eq?(a,b)`

## When to Use

- **Protocol implementation**: When you need domain's default ordering (whatever makes business sense)
- **Custom Ord injection**: When you need different ordering for specific contexts
- Custom sort with `Funx.List.sort/2` (protocol default or custom)
- Range operations (`min`, `max`, `clamp`, `between`)
- Multi-field lexicographic sorting and complex ordering logic

## Anti-Patterns

```elixir
# ❌ Don't use raw operators on structs
if user1 < user2, do: ...  # May raise ArgumentError

# ❌ Don't forget any comparison functions
defimpl Funx.Ord, for: User do
  def lt?(%User{id: id1}, %User{id: id2}), do: id1 < id2
  # Missing le?/2, gt?/2, ge?/2!
end

# ❌ Don't transform comparison result  
contramap(fn result -> not result end)  # Wrong!

# ❌ Don't mix protocols inconsistently
def process(a, b) do
  if a < b do  # Raw operator
    Ord.max(a, b)  # Protocol-based
  end
end
```

## Testing

```elixir
test "Ord laws hold" do
  # Antisymmetry: a <= b and b <= a implies a == b
  assert Ord.le?(user1, user2) and Ord.le?(user2, user1) 
    implies Ord.compare(user1, user2) == :eq
  
  # Transitivity: a <= b and b <= c implies a <= c
  assert Ord.le?(user1, user2) and Ord.le?(user2, user3)
    implies Ord.le?(user1, user3)
  
  # Connexity: either a <= b or b <= a
  assert Ord.le?(user1, user2) or Ord.le?(user2, user1)
end

test "contramap preserves Ord laws" do
  by_age = Ord.contramap(& &1.age)
  user1 = %User{age: 25, name: "Alice"}
  user2 = %User{age: 30, name: "Bob"}
  
  # Contramap projection maintains ordering laws
  assert by_age.lt?.(user1, user2)  # 25 < 30
  assert not by_age.lt?.(user1, user1)  # Anti-reflexive
end

test "monoid composition laws" do
  ord1 = Ord.contramap(& &1.age)
  ord2 = Ord.contramap(& &1.name)
  
  # Lexicographic: age first, then name
  combined = Ord.append(ord1, ord2)
  
  # Same age, different names
  alice = %User{age: 30, name: "Alice"}
  bob = %User{age: 30, name: "Bob"}
  assert combined.lt?.(alice, bob)  # Alice < Bob by name
end
```

## Core Functions

### Protocol Functions

```elixir
# Direct protocol calls
Ord.lt?(a, b)    # less than
Ord.le?(a, b)    # less than or equal  
Ord.gt?(a, b)    # greater than
Ord.ge?(a, b)    # greater than or equal

# These delegate to implementations or fallback to Elixir operators
Ord.lt?(5, 10)              # true (fallback)
Ord.lt?(user1, user2)       # uses User implementation
```

### Utils Functions

```elixir
# Comparison and utilities
Ord.compare(a, b)           # :lt | :eq | :gt
Ord.min(a, b)               # minimum value
Ord.max(a, b)               # maximum value
Ord.clamp(value, min, max)  # bound value within range
Ord.between(value, min, max) # check if in range

# For Enum.sort/2 compatibility  
comparator = Ord.comparator(custom_ord)
Enum.sort(list, comparator)
```

### Transformation Functions

```elixir
# Transform inputs before comparison
by_length = Ord.contramap(&String.length/1)
Ord.max("cat", "zebra", by_length)  # "zebra" (longer)

# Reverse ordering
desc = Ord.reverse()
Ord.min(3, 7, desc)  # 7 (max in normal order)

# Convert to equality
eq = Ord.to_eq()
eq.eq?.(5, 5)  # true (compare(5,5) == :eq)
```

### Composition Functions

```elixir
# Combine orderings lexicographically
age_then_name = Ord.append(
  Ord.contramap(& &1.age),
  Ord.contramap(& &1.name)
)

# Combine list of orderings
multi_sort = Ord.concat([
  Ord.contramap(& &1.priority),
  Ord.contramap(& &1.created_at), 
  Ord.contramap(& &1.id)
])
```

## Integration with Funx.List

```elixir
# Basic sorting
Funx.List.sort([3, 1, 4])  # [1, 3, 4]

# Custom ordering
users = [%User{age: 30}, %User{age: 25}]
by_age = Ord.contramap(& &1.age)
Funx.List.sort(users, by_age)

# Sort and remove duplicates
Funx.List.strict_sort(users, by_age)  # uses Ord.to_eq for dedup

# Multi-field sort
by_age_then_name = Ord.concat([
  Ord.contramap(& &1.age),
  Ord.contramap(& &1.name)
])
Funx.List.sort(users, by_age_then_name)
```

## Built-in Implementations

### Temporal Types

```elixir
# DateTime, Date, Time, NaiveDateTime all have safe implementations
events = [%Event{occurred_at: ~U[2024-01-02 10:00:00Z]}, 
          %Event{occurred_at: ~U[2024-01-01 10:00:00Z]}]

by_time = Ord.contramap(& &1.occurred_at)
Funx.List.sort(events, by_time)  # chronological order
```

### Fallback (Any)

```elixir
# Safe with basic types
Ord.lt?(1, 2)        # true
Ord.lt?("a", "b")    # true  
Ord.lt?([1], [1,2])  # true

# Unsafe with structs/maps - define explicit implementations
# Ord.lt?(%User{}, %User{})  # May raise ArgumentError
```

## Common Patterns

### Multi-field Sorting

```elixir
# Sort by priority (high first), then by created date (old first)
task_ordering = Ord.concat([
  Ord.reverse(Ord.contramap(& &1.priority)),
  Ord.contramap(& &1.created_at)
])

Funx.List.sort(tasks, task_ordering)
```

### Range Operations

```elixir
# Clamp values within bounds
score = Ord.clamp(user_score, 0, 100)

# Check if value is in acceptable range  
valid = Ord.between(temperature, min_temp, max_temp)

# Find extreme values
oldest_user = Enum.reduce(users, &Ord.min(&1, &2, by_age))
```

### Domain-Specific Ordering

```elixir
defmodule Priority do
  @priorities [:low, :medium, :high, :critical]
  
  def to_index(priority), do: Enum.find_index(@priorities, &(&1 == priority))
end

# Order by priority level
by_priority = Ord.contramap(&Priority.to_index/1)
Funx.List.sort(tasks, by_priority)
```

## Performance Considerations

- Protocol dispatch has minimal overhead
- `contramap` creates new functions - avoid in tight loops
- Composition with `concat` chains multiple comparisons
- `Funx.List.sort` is optimized for custom comparators
- Built-in temporal comparisons are efficient

## Best Practices

- Define `Ord` for domain types, not just structs
- Keep `Ord` and `Eq` implementations consistent
- Use `Utils` functions rather than direct protocol calls
- Prefer composition over custom implementations
- Test ordering laws in your implementations
- Document the ordering semantics for domain types

## Ord DSL

The Ord DSL provides a declarative syntax for building complex lexicographic orderings without explicit `contramap`, `concat`, and `reverse` calls.

**Design Philosophy:**

- **Declarative ordering** - Describe what to sort by, not how to sort
- **Compile-time composition** - DSL expands to static `Ord` compositions at compile time
- **Type-safe projections** - Leverages Lens and Prism for safe data access
- **Deterministic tiebreaking** - Automatic identity projection ensures total ordering

**Key Benefits:**

- Clean, readable multi-field sorting
- Automatic handling of nil values with Prism semantics
- Explicit Lens for required fields, atoms for optional fields
- Type filtering with bare struct modules
- Zero runtime overhead - compiles to direct function calls
- Automatic tiebreaker ensures reproducible sorts

### Basic Usage

```elixir
use Funx.Ord

ord do
  asc :name
  desc :age
end
```

### Practical Comparison: Before and After

**With Utils functions (manual composition):**

```elixir
Ord.concat([
  Ord.contramap(Prism.key(:routing_number)),
  Ord.reverse(Ord.contramap(Prism.key(:amount))),
  Ord.contramap(Lens.key(:name))
])
```

**With Ord DSL (declarative):**

```elixir
ord do
  asc :routing_number
  desc :amount
  asc Lens.key(:name)
end
```

The DSL version:

- ✅ More readable (clear sorting intent)
- ✅ More concise (no manual contramap/concat/reverse)
- ✅ Type-safe (compile-time projection validation)
- ✅ Same performance (expands to identical code)

### Supported Projections

- `asc :atom` / `desc :atom` - Field access via `Prism.key/1` (returns `Nothing` for missing keys or nil)
- `asc :atom, or_else: value` - Prism with fallback (replaces `Nothing` with value)
- `asc Lens.key(:field)` - Explicit Lens (total access, raises `KeyError` on missing keys)
- `asc Lens.path([:a, :b])` - Nested Lens (raises on missing keys or nil intermediate values)
- `asc Prism.key(:field)` - Explicit Prism (returns `Maybe`, Nothing < Just with `Maybe.lift_ord`)
- `asc {Prism.key(:field), default}` - Prism tuple (replaces `Nothing` with default)
- `asc &String.length/1` - Function projection
- `asc fn x -> x.field end` - Anonymous function
- `asc MyModule.my_projection()` - Helper function (0-arity)
- `asc MyBehaviour` - Behaviour module projection
- `asc MyBehaviour, opt: value` - Behaviour with options
- `asc MyStruct` - Bare struct module (type filtering)
- `asc my_ord` / `desc my_ord` - Ord variable (compose or reverse existing ord maps)

### DSL Examples

**Basic multi-field sorting:**

```elixir
ord do
  asc :priority
  desc :created_at
  asc :name
end
```

**Handling nil values with or_else:**

```elixir
ord do
  asc :score, or_else: 0
  asc :name
end
```

**Nested field access:**

```elixir
ord do
  asc Lens.path([:address, :city])
  asc :name
end
```

**Type-based partitioning:**

```elixir
# Sort: all Checks first, then CreditCards, each by amount
ord do
  desc Check
  asc :amount
end
```

**Custom behaviour projection:**

```elixir
defmodule NameLength do
  @behaviour Funx.Ord.Dsl.Behaviour

  @impl true
  def project(person, _opts), do: String.length(person.name)
end

ord do
  asc NameLength
  asc :name
end
```

**With behaviour options:**

```elixir
defmodule WeightedScore do
  @behaviour Funx.Ord.Dsl.Behaviour

  @impl true
  def project(item, opts) do
    weight = Keyword.get(opts, :weight, 1.0)
    (item.score || 0) * weight
  end
end

ord do
  desc WeightedScore, weight: 2.0
end
```

### Projection Type Selection Guide

**Use atoms (`:field`) when:**

- Field might be missing or nil, and you want `Nothing < Just` semantics (`Maybe.lift_ord`)
- You want safe, forgiving data access (no exceptions)
- You don't need to enforce field existence

**Use Lens when:**

- Field must exist (domain invariant)
- You want fail-fast on missing keys (raises `KeyError`)
- You need nested field access with total guarantees

**Use Prism when:**

- You need to work with sum types (variants)
- You want explicit partial access with Maybe semantics
- You're composing with other Prisms
- You need type-safe pattern matching on variants

**Use functions when:**

- You need custom transformation logic
- Projection doesn't map to a simple field
- You're computing derived values

**Use behaviours when:**

- Logic is complex and reusable
- You need parameterized projections
- You want to share projection logic across modules

**Use bare struct modules when:**

- You need type-based partitioning
- Sorting heterogeneous lists by type
- You want all values of one type before another

### Lens vs Prism vs Atoms

**Critical difference in nil handling:**

```elixir
# Atom: Uses Prism (Nothing < Just)
ord do
  asc :value
end
# nil values sort first

# Explicit Lens: Uses Elixir term ordering
ord do
  asc Lens.key(:value)
end
# nil (atom) > numbers in Elixir's term ordering

# Explicit Prism with or_else: Replace nil with default
ord do
  asc :value, or_else: 0
end
# nil becomes 0 for comparison
```

**When to use each:**

- **Lens** - Lawful total optic. Unconditional extraction. Raises `KeyError` on missing keys, or when intermediate path values are nil.
- **Prism** - Lawful partial optic. Returns `Maybe` (`Nothing` for missing/nil, `Just(value)` for present). Primary use: sum types (variants).
- **Atoms** - Convenience syntax using `Prism.key/1`. Safe for optional fields with `Maybe.lift_ord` semantics.
- **Prism with or_else** - Replaces `Nothing` with a default value before comparison.

### Compile-Time Safety

**Valid or_else usage:**

```elixir
# ✅ Atoms accept or_else
ord do
  asc :score, or_else: 0
end

# ✅ Explicit Prisms accept or_else
ord do
  asc Prism.key(:score), or_else: 0
end

# ✅ Helper functions returning Prisms accept or_else
ord do
  asc ProjectionHelpers.score_prism(), or_else: 0
end
```

**Invalid or_else usage (compile error):**

```elixir
# ❌ Lens cannot use or_else
ord do
  asc Lens.key(:name), or_else: "Unknown"
end

# ❌ Functions cannot use or_else
ord do
  asc &String.length/1, or_else: 0
end

# ❌ Behaviours cannot use or_else
ord do
  asc MyBehaviour, or_else: 0
end

# ❌ Redundant or_else with tuple syntax
ord do
  asc {Prism.key(:score), 0}, or_else: 10
end
```

### Implicit Identity Tiebreaker

The DSL automatically appends an identity projection as the final tiebreaker:

```elixir
ord do
  asc :name
end
```

Compiles to:

```elixir
Ord.concat([
  Ord.contramap(Prism.key(:name)),
  Ord.contramap(fn x -> x end)  # implicit identity
])
```

This ensures:

- **Deterministic ordering** - Same input always produces same output
- **Total ordering** - All values can be compared
- **No arbitrary tiebreaking** - Uses value's Ord protocol implementation
- **Reproducible sorts** - Consistent across runs and environments

### Working with Lists

```elixir
people = [
  %Person{name: "Charlie", age: 30, score: nil},
  %Person{name: "Alice", age: 25, score: 100},
  %Person{name: "Bob", age: 30, score: 50}
]

ord_person =
  ord do
    asc :name
    desc :age
    asc :score, or_else: 0
  end

# With Funx.List
Funx.List.sort(people, ord_person)

# With Enum.sort/2
Enum.sort(people, Ord.comparator(ord_person))

# Find min/max
Funx.List.min!(people, ord_person)
Funx.List.max!(people, ord_person)
```

### Helper Functions Pattern

Define reusable projections as 0-arity functions:

```elixir
defmodule ProjectionHelpers do
  alias Funx.Optics.{Lens, Prism}

  def name_lens, do: Lens.key(:name)
  def age_lens, do: Lens.key(:age)
  def score_prism, do: Prism.key(:score)
  def score_with_default, do: {Prism.key(:score), 0}
end

# Use in DSL
ord do
  asc ProjectionHelpers.age_lens()
  asc ProjectionHelpers.score_with_default()
  asc ProjectionHelpers.name_lens()
end
```

### Ord Variables (Composing Orderings)

You can use existing ord maps as projections within the DSL. This allows you to build complex orderings by composing and reusing simpler ones:

```elixir
# Define a base ordering
base_ord =
  ord do
    asc :name
    desc :age
  end

# Reuse it in another ord
combined_ord =
  ord do
    asc :priority
    asc base_ord  # Uses base_ord directly
  end

# Reverse an existing ord
reversed_ord =
  ord do
    desc base_ord  # Reverses the base ordering
  end
```

**Common Patterns:**

```elixir
# Build complex orderings from simple ones
payment_amount_ord =
  ord do
    asc Prism.key(:credit_card_payment)
    asc Prism.key(:credit_card_refund)
    asc Prism.key(:check_payment)
    asc Prism.key(:check_refund)
  end

# Easily reverse without rebuilding
payment_amount_desc =
  ord do
    desc payment_amount_ord
  end

# Extend a base ordering with additional criteria
extended_ord =
  ord do
    asc base_ord
    asc :created_at
    asc :id
  end

# Compose multiple ord variables
complex_ord =
  ord do
    asc priority_ord
    desc timestamp_ord
    asc name_ord
  end
```

**What works as an ord variable:**

```elixir
# ✅ Ord maps created with ord do...end
my_ord = ord do asc :name end

# ✅ Ord maps from Utils.contramap
length_ord = Ord.contramap(&String.length/1)

# ✅ Ord maps from Utils.reverse
desc_ord = Ord.reverse(my_ord)

# ✅ Ord maps from Utils.concat
combined = Ord.concat([ord1, ord2])
```

**Runtime validation:**

Ord variables are validated when the ord is created. Invalid values raise helpful errors:

```elixir
invalid = "not an ord"

ord do
  asc invalid  # RuntimeError: Expected an Ord map, got: "not an ord"
end
```

**Note:** Ord variables include their implicit identity tiebreaker, so composing them preserves their complete ordering semantics.

### Type Filtering with Bare Struct Modules

Sort heterogeneous lists by type first, then by fields:

```elixir
payments = [
  %CreditCard{name: "Alice", amount: 300},
  %Check{name: "Frank", amount: 100},
  %CreditCard{name: "Bob", amount: 100},
  %Check{name: "Edith", amount: 400}
]

ord_checks_first =
  ord do
    desc Check  # All Checks sort before CreditCards
    asc :amount
    asc :name
  end

Funx.List.sort(payments, ord_checks_first)
# Result: [Check(Frank), Check(Edith), CreditCard(Bob), CreditCard(Alice)]
```

### Complex Nested Data

```elixir
employees = [
  %Employee{
    name: "Alice",
    company: %Company{
      name: "Acme",
      address: %Address{city: "Austin", state: "TX"}
    }
  },
  %Employee{
    name: "Bob",
    company: %Company{
      name: "Widgets",
      address: %Address{city: "Boston", state: "MA"}
    }
  }
]

ord_by_company_city =
  ord do
    asc Lens.path([:company, :address, :city])
    asc :name
  end

Funx.List.sort(employees, ord_by_company_city)
```

### Empty Ord Block

An empty `ord` block creates an identity ordering:

```elixir
ord_identity =
  ord do
  end

Ord.compare(a, b, ord_identity)  # Always :eq
```

### When to Use the DSL

**✅ Use the DSL when:**

- You need multi-field lexicographic sorting
- You want declarative, readable ordering definitions
- You're combining different projection types
- You need nil-safe field access
- You want compile-time validation
- You prefer pipeline-friendly syntax

**❌ Use Utils functions when:**

- You only need single-field sorting (DSL may be overkill)
- You're building dynamic orderings at runtime (DSL is compile-time only)
- You need fine-grained control over composition
- You prefer explicit function composition over macro expansion
- You're implementing reusable combinator libraries

### Common DSL Patterns

**Paginated data sorting:**

```elixir
ord_pagination =
  ord do
    desc :priority
    asc :created_at
    asc :id  # Stable tiebreaker
  end
```

**Dashboard sorting:**

```elixir
ord_tasks =
  ord do
    desc :is_pinned, or_else: false
    asc :status
    desc :updated_at
  end
```

**Multi-level grouping:**

```elixir
ord_reports =
  ord do
    asc Lens.path([:department, :name])
    asc Lens.path([:team, :name])
    desc :performance_score, or_else: 0
  end
```

### Formatter Configuration

Funx exports formatter rules for clean DSL formatting. Add to `.formatter.exs`:

```elixir
[
  import_deps: [:funx],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

This formats DSL code cleanly without parentheses:

```elixir
# With formatter rules (clean)
ord do
  asc :name
  desc :age
end

# Without formatter rules (parentheses added)
ord() do
  asc(:name)
  desc(:age)
end
```

### Comparison with Manual Composition

The DSL is syntactic sugar over Utils functions:

```elixir
# DSL
ord do
  asc :name
  desc :age
  asc :score, or_else: 0
end

# Equivalent Utils composition
Ord.concat([
  Ord.contramap(Prism.key(:name)),
  Ord.reverse(Ord.contramap(Prism.key(:age))),
  Ord.contramap({Prism.key(:score), 0}),
  Ord.contramap(fn x -> x end)  # implicit identity
])
```

Both compile to identical code - the DSL just makes it more readable.

### Testing DSL Orderings

```elixir
test "multi-field ordering" do
  alice_30 = %Person{name: "Alice", age: 30}
  alice_25 = %Person{name: "Alice", age: 25}
  bob_30 = %Person{name: "Bob", age: 30}

  ord_person =
    ord do
      asc :name
      desc :age
    end

  # Alice comes before Bob (name)
  assert Ord.compare(alice_30, bob_30, ord_person) == :lt

  # Same name, 30 > 25 in desc age
  assert Ord.compare(alice_30, alice_25, ord_person) == :lt

  # Verify identity tiebreaker
  assert Ord.compare(alice_30, alice_30, ord_person) == :eq
end

test "nil handling with or_else" do
  with_score = %Item{name: "A", score: 100}
  without_score = %Item{name: "B", score: nil}

  ord_item =
    ord do
      asc :score, or_else: 0
    end

  # nil becomes 0, so 0 < 100
  assert Ord.compare(without_score, with_score, ord_item) == :lt
end

test "type filtering" do
  check = %Check{name: "Alice", amount: 100}
  cc = %CreditCard{name: "Bob", amount: 200}

  ord_checks_first =
    ord do
      desc Check
      asc :amount
    end

  # All Checks before CreditCards
  assert Ord.compare(check, cc, ord_checks_first) == :lt
end
```

### Performance Characteristics

- **Compile-time expansion** - DSL compiles to static function calls
- **Zero runtime overhead** - No interpretation or dispatch
- **Efficient composition** - Uses monoid concatenation
- **Lazy evaluation** - Short-circuits on first non-equal comparison
- **Memory efficient** - No intermediate allocations

### Summary

The Ord DSL provides declarative multi-field sorting:

**Core Operations:**

- `asc <projection>` - Sort ascending
- `desc <projection>` - Sort descending
- `or_else: value` - Replaces `Nothing` with fallback value (atoms and Prisms only)

**Key Patterns:**

- Use atoms for optional fields (`Nothing < Just` with `Maybe.lift_ord`)
- Use Lens for required fields (raises `KeyError` on missing keys)
- Use Prism explicitly for sum types (variants) with partial access
- Use Prism with or_else for optional fields with specific defaults
- Use behaviours for complex, reusable projection logic
- Use bare struct modules for type-based partitioning (heterogeneous lists)
- Automatic identity tiebreaker ensures deterministic total ordering

**Remember:** The Ord DSL compiles to Utils function calls at compile time - use whichever syntax is clearer for your use case.
