# `Funx.Eq` Usage Rules

## Core Concepts

**Protocol + Custom Eq Pattern**: Use both together for maximum flexibility

- **Protocol implementation** = domain's default equality (whatever makes business sense)
- **Custom Eq injection** = context-specific equality when needed
- **Key insight**: Protocol provides sensible defaults, custom Eq provides flexibility

**Contramap**: Contravariant functor - transforms inputs before comparison

- `contramap(& &1.id, Eq)` compares by ID field only
- Mathematical dual of `map` - transforms "backwards" through the data flow
- Key pattern: transform the input, not the comparison result

**Utils Pattern**: Inject custom Eq logic or default to protocol

- `Eq.Utils.eq?(a, b, custom_eq)` - uses custom_eq
- `Eq.Utils.eq?(a, b)` - uses protocol dispatch

**Monoid Composition**: Combine equality checks

- `append_all/any(eq1, eq2)` - combine two (FALSE/TRUE-biased)
- `concat_all/any([eq1, eq2, eq3])` - combine list (FALSE/TRUE-biased)

## Quick Patterns

```elixir
# STEP 1: Implement protocol for domain's default equality
defimpl Funx.Eq, for: User do
  def eq?(%User{id: id1}, %User{id: id2}), do: Funx.Eq.eq?(id1, id2)
  def not_eq?(a, b), do: not eq?(a, b)
end

# STEP 2: Use protocol directly for default equality
Eq.eq?(user1, user2)  # Uses protocol (by ID)
List.uniq(users)      # Uses protocol default

# STEP 3: Inject custom Eq for specific contexts
by_name = Eq.Utils.contramap(& &1.name)
Eq.Utils.eq?(user1, user2, by_name)  # Compare by name instead
List.uniq(users, by_name)            # Dedupe by name, not ID

# Combine fields
name_and_age = Eq.Utils.concat_all([
  Eq.Utils.contramap(& &1.name),
  Eq.Utils.contramap(& &1.age)
])

# Use with Funx.List
Funx.List.uniq(users, by_id)
```

## Key Rules

- **IMPLEMENT PROTOCOL** for domain's default equality (whatever makes business sense)
- **USE CUSTOM EQ** when you need different equality for specific operations
- **MUST implement both** `eq?/2` and `not_eq?/2` (no optional defaults)
- **Best practice**: `not_eq?(a, b) = not eq?(a, b)`
- Use `contramap/2` to transform inputs before comparison
- Use monoid functions for composition: `append_all/any`, `concat_all/any`
- Pattern: Protocol for defaults, Utils injection for flexibility

## When to Use

- **Protocol implementation**: When you need domain's default equality (whatever makes business sense, not structural equality)
- **Custom Eq injection**: When you need different equality for specific contexts
- Deduplication with `Funx.List.uniq/2` (protocol default or custom)
- Set operations (`union`, `intersection`, etc.)
- Context-specific filtering and comparison logic

## Anti-Patterns

```elixir
# ❌ Don't mix == and Eq.eq?
if user1 == user2 and Eq.eq?(user1.name, user2.name), do: ...

# ❌ Don't forget not_eq?/2
defimpl Funx.Eq, for: User do
  def eq?(%User{id: id1}, %User{id: id2}), do: id1 == id2
  # Missing not_eq?/2!
end

# ❌ Don't transform comparison result
contramap(fn result -> not result end)  # Wrong!
```

## Testing

```elixir
test "Eq laws hold" do
  # Reflexivity: a == a
  assert Eq.eq?(user, user)
  
  # Symmetry: a == b implies b == a  
  assert Eq.eq?(user1, user2) == Eq.eq?(user2, user1)
  
  # Complement: eq? and not_eq? are opposites
  assert Eq.eq?(user1, user2) == not Eq.not_eq?(user1, user2)
end

test "contramap preserves Eq laws" do
  by_id = Eq.Utils.contramap(& &1.id)
  user1 = %User{id: 1, name: "Alice"}
  user2 = %User{id: 1, name: "Bob"}  # Same ID, different name
  
  # Contramap projection maintains equality laws
  assert by_id.eq?.(user1, user2)  # Same ID
  assert by_id.eq?.(user1, user1)  # Reflexive
end

test "monoid composition laws" do
  eq1 = Eq.Utils.contramap(& &1.name)
  eq2 = Eq.Utils.contramap(& &1.age)
  
  # Monoid bias behavior
  all_eq = Eq.Utils.concat_all([eq1, eq2])  # FALSE-biased
  any_eq = Eq.Utils.concat_any([eq1, eq2])  # TRUE-biased
  
  person1 = %{name: "Alice", age: 25}
  person2 = %{name: "Alice", age: 30}  # Name matches, age differs
  
  assert any_eq.eq?.(person1, person2)  # TRUE-bias: stops at name match
  refute all_eq.eq?.(person1, person2) # FALSE-bias: fails on age difference
end
```

## Fallback Behavior

- **Any protocol**: Uses Elixir's `==` and `!=` for primitive types
- **Custom types**: Define explicit `Eq` implementation for domain logic
- **Time types**: Built-in instances use standard library comparison

## Summary

`Funx.Eq` provides **extensible, composable equality** for domain semantics beyond structural `==`:

- **Contramap** (contravariant functor): Transform inputs before comparison
- **Monoid composition**: Combine equality checks with FALSE/TRUE-biased operations  
- **Utils injection**: `Eq.Utils.eq?(a, b, custom_eq)` pattern for flexible equality
- **Protocol + fallback**: Custom domain logic with `Any` fallback for primitives
- **Mathematical foundation**: Preserves equality laws through transformations and composition

**Canon**: Use `contramap` for projections, monoid functions for composition, Utils injection for flexibility.
