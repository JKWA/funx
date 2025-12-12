# `Funx.Optics.Prism` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Prism**: A partial optic for focusing on branches of data structures

- **Partial access**: The focus may or may not be present (unlike Lens which is total)
- **Two operations**: `preview/2` (extract, returns Maybe) and `review/2` (reconstruct from focus)
- **Lawful**: Must satisfy round-trip laws for preview/review
- **Compositional**: Prisms compose via `compose/2` or `concat/1`

**Prism vs Lens:**

- **Prism**: Partial access, returns Maybe, reconstructs minimal structure
- **Lens**: Total access, always succeeds, updates while preserving structure
- Use Prism when absence is normal; use Lens when absence is a bug

**Key Path Syntax:**

- `:atom` - Plain key access (works with maps and structs)
- `{Module, :atom}` - Struct-typed access (verifies struct type, then accesses key)
- `path([{User, :profile}, {Profile, :age}])` expands to composition of struct and key prisms

**Prism Laws:**

1. **Review-Preview**: `preview(review(b, p), p) = Just(b)` (round-trip from value)
2. **Preview-Review**: If `preview(s, p) = Just(a)`, then `preview(review(a, p), p) = Just(a)` (round-trip preserves focus)

**Important**: Review constructs the *minimal* structure needed for preview, not the original structure. Other fields are lost.

## LLM Decision Guide: When to Use Prisms

**✅ Use Prism when:**

- Accessing optional/nullable fields (user profile, config value)
- Working with variants or sum types (selecting one case from many)
- Filtering data (only process values matching a predicate)
- Absence is normal and expected in the domain
- Need to compose partial accessors
- User says: "optional", "might not have", "filter", "only if", "when present"

**❌ Use Lens when:**

- Field access should always succeed
- Need to update values while preserving structure
- Absence would indicate a bug
- Working with required fields
- User says: "update", "set field", "modify in place"

**⚡ Prism Strategy Decision:**

- **Simple key access**: `Prism.key(:name)` for single map/struct field
- **Nested paths**: `Prism.path([:user, :profile, :email])` for plain maps
- **Struct-typed paths**: `Prism.path([{User, :profile}, {Profile, :email}])` for typed reconstruction
- **Filtering**: `Prism.filter(&(&1 > 0))` for conditional matching
- **List head**: `Prism.some()` for non-empty list access
- **Struct variants**: `Prism.struct(User)` for selecting specific struct types
- **Composition**: `Prism.compose(p1, p2)` or `Prism.concat([p1, p2, p3])`

**⚙️ Function Choice Guide:**

- **Extract value**: `preview/2` returns `Just(value)` or `Nothing`
- **Reconstruct**: `review/2` builds minimal structure from focus
- **Compose prisms**: `compose/2` for two, `concat/1` for multiple
- **Custom prisms**: `make/2` with preview and review functions

## LLM Context Clues

**User language → Prism patterns:**

- "optional user profile" → `Prism.path([{User, :profile}])`
- "get email if present" → `Prism.preview(user, Prism.key(:email))`
- "only process positive numbers" → `Prism.filter(&(&1 > 0))`
- "first item if list not empty" → `Prism.some()`
- "access nested optional field" → `Prism.path([:data, :config, :timeout])`
- "extract from specific struct type" → `Prism.struct(Account)`
- "chain optional lookups" → `Prism.compose(outer_prism, inner_prism)`

## Quick Reference

- Use `preview/2` to extract - returns `Just(value)` or `Nothing`
- Use `review/2` to reconstruct minimal structure from focus
- Chain prisms with `compose/2` - failures propagate automatically
- Plain path: `path([:a, :b, :c])` for maps
- Typed path: `path([{User, :profile}, {Profile, :age}])` for structs
- Filter: `filter(&predicate/1)` for conditional matching
- **IMPORTANT**: `{Module, :field}` requires `:field` exists in `Module` for lawfulness
- Prisms return Maybe - use `Monad.bind/2`, `Monad.map/2`, or pattern match
- Review loses data outside focus - this is expected and lawful

## Overview

`Funx.Optics.Prism` provides lawful partial optics for focusing on branches of data structures.

Use Prism for:

- Optional fields where absence is normal
- Variant selection (choosing one case from many possibilities)
- Filtered data access (only process matching values)
- Compositional partial access
- Situations where failure to find a value is expected

**Key insight**: Prisms model *partial* access where the focus may not exist. Unlike Lens (which always succeeds), Prism returns Maybe to represent presence/absence. Review constructs the minimal structure needed for the focus, not the full original structure.

## Constructors

### `key/1` - Focus on Map/Struct Key

Creates a prism focusing on a single key:

```elixir
alias Funx.Optics.Prism
alias Funx.Monad.Maybe

p = Prism.key(:name)

# Preview extracts if present
Prism.preview(%{name: "Alice"}, p)
#=> Just("Alice")

Prism.preview(%{email: "alice@example.com"}, p)
#=> Nothing (key missing)

Prism.preview(%{name: nil}, p)
#=> Nothing (nil treated as absent)

# Review constructs minimal structure
Prism.review("Alice", p)
#=> %{name: "Alice"}
```

### `path/1` - Focus on Nested Path

Creates a prism for nested access with optional struct typing:

```elixir
# Plain map path
p1 = Prism.path([:user, :profile, :email])
Prism.review("alice@example.com", p1)
#=> %{user: %{profile: %{email: "alice@example.com"}}}

# Struct-typed path
defmodule Profile, do: defstruct [:email, :age]
defmodule User, do: defstruct [:name, :profile]

p2 = Prism.path([{User, :profile}, {Profile, :email}])
Prism.review("alice@example.com", p2)
#=> %User{profile: %Profile{email: "alice@example.com", age: nil}, name: nil}

# Mixed: struct then plain
p3 = Prism.path([{User, :name}])
Prism.review("Alice", p3)
#=> %User{name: "Alice", profile: nil}
```

**Syntax:**
- `:atom` - Plain key access
- `{Module, :atom}` - Expands to `compose(struct(Module), key(:atom))`

**IMPORTANT**: Only use `{Module, :field}` when `:field` exists in `Module`. Using non-existent fields may violate prism laws.

### `struct/1` - Focus on Struct Type

Creates a prism that selects a specific struct type:

```elixir
defmodule Account, do: defstruct [:id, :balance]

p = Prism.struct(Account)

# Preview succeeds only for matching struct
Prism.preview(%Account{id: 1, balance: 100}, p)
#=> Just(%Account{id: 1, balance: 100})

Prism.preview(%{id: 1, balance: 100}, p)
#=> Nothing (plain map, not Account struct)

# Review promotes map to struct
Prism.review(%{id: 2, balance: 200}, p)
#=> %Account{id: 2, balance: 200}
```

**Use case**: Modeling sum types - selecting one variant from multiple possibilities.

### `filter/1` - Focus on Matching Values

Creates a prism that succeeds only when predicate returns true:

```elixir
positive = Prism.filter(&(&1 > 0))

# Preview succeeds when predicate matches
Prism.preview(42, positive)
#=> Just(42)

Prism.preview(-5, positive)
#=> Nothing

# Review returns value unchanged (filters don't validate on review)
Prism.review(100, positive)
#=> 100

Prism.review(-10, positive)
#=> -10 (filter doesn't validate on review)
```

**Note**: Filters don't validate during review - they only check during preview.

### `some/0` - Focus on List Head

Creates a prism focusing on the first element of a non-empty list:

```elixir
head = Prism.some()

# Preview extracts first element
Prism.preview([1, 2, 3], head)
#=> Just(1)

Prism.preview([], head)
#=> Nothing

# Review creates singleton list
Prism.review(:value, head)
#=> [:value]
```

### `none/0` - Never Matches

Creates a prism that always fails (monoid annihilator):

```elixir
never = Prism.none()

Prism.preview(anything, never)
#=> Nothing (always fails)

Prism.review(value, never)
#=> nil
```

**Use case**: Identity element for prism composition algebra.

### `make/2` - Custom Prisms

Creates a prism from preview and review functions:

```elixir
alias Funx.Monad.Maybe

# Prism for positive numbers stored as strings
positive_str = Prism.make(
  fn
    str when is_binary(str) ->
      case Integer.parse(str) do
        {n, ""} when n > 0 -> Maybe.just(n)
        _ -> Maybe.nothing()
      end
    _ -> Maybe.nothing()
  end,
  fn n -> Integer.to_string(n) end
)

Prism.preview("42", positive_str)
#=> Just(42)

Prism.preview("-5", positive_str)
#=> Nothing

Prism.review(100, positive_str)
#=> "100"
```

**IMPORTANT**: You are responsible for ensuring preview/review obey prism laws. They must round-trip correctly.

## Core Operations

### `preview/2` - Extract Focus

Attempts to extract the focused value, returning Maybe:

```elixir
data = %{user: %{profile: %{email: "alice@example.com"}}}
p = Prism.path([:user, :profile, :email])

Prism.preview(data, p)
#=> Just("alice@example.com")

# Fails when path incomplete
incomplete = %{user: %{}}
Prism.preview(incomplete, p)
#=> Nothing
```

**Returns**: `Just(value)` on success, `Nothing` on failure

### `review/2` - Reconstruct Structure

Reconstructs the minimal structure needed to contain the focus:

```elixir
p = Prism.path([{User, :profile}, {Profile, :age}])

Prism.review(30, p)
#=> %User{
#     profile: %Profile{age: 30, age: nil},
#     name: nil
#   }
```

**Important**: Review constructs the *minimal* structure. Other fields get default values. Original data is lost.

## Composition

### `compose/2` - Compose Two Prisms

Composes two prisms sequentially:

```elixir
# Build composed prism
user_prism = Prism.struct(User)
name_prism = Prism.key(:name)
user_name = Prism.compose(user_prism, name_prism)

# Preview: outer first, then inner
Prism.preview(%User{name: "Alice"}, user_name)
#=> Just("Alice")

# Review: inner first, then outer (reversed!)
Prism.review("Bob", user_name)
#=> %User{name: "Bob", profile: nil}
```

**Preview direction**: left to right (outer → inner)
**Review direction**: right to left (inner → outer)

### `concat/1` - Compose Multiple Prisms

Composes a list of prisms:

```elixir
positive = Prism.filter(&(&1 > 0))
even = Prism.filter(&(rem(&1, 2) == 0))
small = Prism.filter(&(&1 < 100))

composed = Prism.concat([positive, even, small])

Prism.preview(4, composed)
#=> Just(4)

Prism.preview(-2, composed)
#=> Nothing (fails first filter)
```

**Equivalent to**: `compose(compose(p1, p2), p3)`

## Working with Maybe Results

Prism operations return Maybe, so use Maybe operations to work with results:

```elixir
import Funx.Monad
alias Funx.Monad.Maybe

user = %{profile: %{email: "alice@example.com"}}
p = Prism.path([:profile, :email])

# Extract with default
user
|> Prism.preview(p)
|> Maybe.get_or_else("no-email@example.com")
#=> "alice@example.com"

# Transform if present
user
|> Prism.preview(p)
|> map(&String.upcase/1)
#=> Just("ALICE@EXAMPLE.COM")

# Chain with other Maybe operations
user
|> Prism.preview(p)
|> bind(&validate_email/1)  # returns Maybe
```

## Common Patterns

### Optional Field Access

```elixir
# Safe access to potentially missing fields
config = %{database: %{timeout: 5000}}

timeout_prism = Prism.path([:database, :timeout])
Prism.preview(config, timeout_prism)
|> Maybe.get_or_else(3000)
#=> 5000
```

### Struct Type Selection

```elixir
# Select specific struct type from mixed data
defmodule CreditCard, do: defstruct [:number]
defmodule BankAccount, do: defstruct [:routing]

cc_prism = Prism.struct(CreditCard)
payment = %CreditCard{number: "1234"}

Prism.preview(payment, cc_prism)
#=> Just(%CreditCard{number: "1234"})
```

### Filtering Data

```elixir
# Process only values matching criteria
active_user = Prism.filter(&(&1.active == true))

users
|> Enum.map(&Prism.preview(&1, active_user))
|> Maybe.concat()  # Extract all Just values
```

### Nested Struct Access with Type Safety

```elixir
# Build typed paths for reconstruction
defmodule Address, do: defstruct [:street, :city]
defmodule Company, do: defstruct [:name, :address]

city_prism = Prism.path([{Company, :address}, {Address, :city}])

# Reconstruct with proper struct types
Prism.review("San Francisco", city_prism)
#=> %Company{
#     name: nil,
#     address: %Address{street: nil, city: "San Francisco"}
#   }
```

## Anti-Patterns

**❌ Don't use invalid struct fields:**

```elixir
# BAD: :nonexistent is not a field in User
p = Prism.path([{User, :nonexistent}])
# Violates prism laws - Kernel.struct drops invalid keys
```

**❌ Don't expect review to preserve original data:**

```elixir
# BAD: Expecting profile to be preserved
user = %User{name: "Alice", profile: %Profile{age: 30}}
p = Prism.path([{User, :name}])

Prism.review("Bob", p)
# Returns: %User{name: "Bob", profile: nil}
# Profile is lost - this is correct prism behavior!
```

**❌ Don't use Prism for total access:**

```elixir
# BAD: Use Lens instead when field should always exist
required_field_prism = Prism.key(:id)
# If :id should always be present, use Lens.key!(:id) instead
```

**✅ Do use valid struct fields:**

```elixir
# GOOD: :name is a field in User
p = Prism.path([{User, :name}])
```

**✅ Do understand review constructs minimal structure:**

```elixir
# GOOD: Expecting only the focus to be preserved
p = Prism.path([{User, :name}])
result = Prism.review("Bob", p)
# result = %User{name: "Bob", profile: nil}
# This is correct - review only preserves the focus
```

**✅ Do use Prism for partial access:**

```elixir
# GOOD: Prism for optional fields
optional_email = Prism.path([:user, :email])
Prism.preview(data, optional_email)
# Returns Maybe - perfect for optional data
```

## Implementation Note

The `path/1` function is syntactic sugar for `concat`:

```elixir
# These are equivalent:
Prism.path([{User, :profile}, {Profile, :age}])

Prism.concat([
  Prism.struct(User),
  Prism.key(:profile),
  Prism.struct(Profile),
  Prism.key(:age)
])
```

This compositionality ensures prism laws are preserved through composition.
