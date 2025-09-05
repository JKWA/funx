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

- `Ord.Utils.compare(a, b, custom_ord)` - uses custom_ord
- `Ord.Utils.compare(a, b)` - uses protocol dispatch

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
by_age = Ord.Utils.contramap(& &1.age)
Ord.Utils.compare(user1, user2, by_age)  # Compare by age instead
List.sort(users, by_age)                 # Sort by age, not joined_at

# Combine fields lexicographically
age_then_name = Ord.Utils.concat([
  Ord.Utils.contramap(& &1.age),
  Ord.Utils.contramap(& &1.name)
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
    Ord.Utils.max(a, b)  # Protocol-based
  end
end
```

## Testing

```elixir
test "Ord laws hold" do
  # Antisymmetry: a <= b and b <= a implies a == b
  assert Ord.le?(user1, user2) and Ord.le?(user2, user1) 
    implies Ord.Utils.compare(user1, user2) == :eq
  
  # Transitivity: a <= b and b <= c implies a <= c
  assert Ord.le?(user1, user2) and Ord.le?(user2, user3)
    implies Ord.le?(user1, user3)
  
  # Connexity: either a <= b or b <= a
  assert Ord.le?(user1, user2) or Ord.le?(user2, user1)
end

test "contramap preserves Ord laws" do
  by_age = Ord.Utils.contramap(& &1.age)
  user1 = %User{age: 25, name: "Alice"}
  user2 = %User{age: 30, name: "Bob"}
  
  # Contramap projection maintains ordering laws
  assert by_age.lt?.(user1, user2)  # 25 < 30
  assert not by_age.lt?.(user1, user1)  # Anti-reflexive
end

test "monoid composition laws" do
  ord1 = Ord.Utils.contramap(& &1.age)
  ord2 = Ord.Utils.contramap(& &1.name)
  
  # Lexicographic: age first, then name
  combined = Ord.Utils.append(ord1, ord2)
  
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
Ord.Utils.compare(a, b)           # :lt | :eq | :gt
Ord.Utils.min(a, b)               # minimum value
Ord.Utils.max(a, b)               # maximum value
Ord.Utils.clamp(value, min, max)  # bound value within range
Ord.Utils.between(value, min, max) # check if in range

# For Enum.sort/2 compatibility  
comparator = Ord.Utils.comparator(custom_ord)
Enum.sort(list, comparator)
```

### Transformation Functions

```elixir
# Transform inputs before comparison
by_length = Ord.Utils.contramap(&String.length/1)
Ord.Utils.max("cat", "zebra", by_length)  # "zebra" (longer)

# Reverse ordering
desc = Ord.Utils.reverse()
Ord.Utils.min(3, 7, desc)  # 7 (max in normal order)

# Convert to equality
eq = Ord.Utils.to_eq()
eq.eq?.(5, 5)  # true (compare(5,5) == :eq)
```

### Composition Functions

```elixir
# Combine orderings lexicographically
age_then_name = Ord.Utils.append(
  Ord.Utils.contramap(& &1.age),
  Ord.Utils.contramap(& &1.name)
)

# Combine list of orderings
multi_sort = Ord.Utils.concat([
  Ord.Utils.contramap(& &1.priority),
  Ord.Utils.contramap(& &1.created_at), 
  Ord.Utils.contramap(& &1.id)
])
```

## Integration with Funx.List

```elixir
# Basic sorting
Funx.List.sort([3, 1, 4])  # [1, 3, 4]

# Custom ordering
users = [%User{age: 30}, %User{age: 25}]
by_age = Ord.Utils.contramap(& &1.age)
Funx.List.sort(users, by_age)

# Sort and remove duplicates
Funx.List.strict_sort(users, by_age)  # uses Ord.Utils.to_eq for dedup

# Multi-field sort
by_age_then_name = Ord.Utils.concat([
  Ord.Utils.contramap(& &1.age),
  Ord.Utils.contramap(& &1.name)
])
Funx.List.sort(users, by_age_then_name)
```

## Built-in Implementations

### Temporal Types

```elixir
# DateTime, Date, Time, NaiveDateTime all have safe implementations
events = [%Event{occurred_at: ~U[2024-01-02 10:00:00Z]}, 
          %Event{occurred_at: ~U[2024-01-01 10:00:00Z]}]

by_time = Ord.Utils.contramap(& &1.occurred_at)
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
task_ordering = Ord.Utils.concat([
  Ord.Utils.reverse(Ord.Utils.contramap(& &1.priority)),
  Ord.Utils.contramap(& &1.created_at)
])

Funx.List.sort(tasks, task_ordering)
```

### Range Operations

```elixir
# Clamp values within bounds
score = Ord.Utils.clamp(user_score, 0, 100)

# Check if value is in acceptable range  
valid = Ord.Utils.between(temperature, min_temp, max_temp)

# Find extreme values
oldest_user = Enum.reduce(users, &Ord.Utils.min(&1, &2, by_age))
```

### Domain-Specific Ordering

```elixir
defmodule Priority do
  @priorities [:low, :medium, :high, :critical]
  
  def to_index(priority), do: Enum.find_index(@priorities, &(&1 == priority))
end

# Order by priority level
by_priority = Ord.Utils.contramap(&Priority.to_index/1)
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
