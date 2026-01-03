# `Funx.Optics.Traversal` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Traversal**: A multi-focus optic for targeting multiple locations in a data structure as a single optic

- **Multi-focus**: Combines multiple optics (Lens or Prism) to work with several locations at once
- **Two modes**: Collection mode (`to_list/2`) and enforcement mode (`to_list_maybe/2`)
- **Order preservation**: Foci are extracted in combine order
- **Compositional**: Built by combining existing Lens and Prism optics
- **Lawful**: Inherits laws from constituent lenses and prisms

**Traversal vs Lens vs Prism:**

- **Traversal**: Multi-focus, extracts from multiple locations, two modes (collect vs enforce)
- **Lens**: Single total focus, always succeeds (or raises), updates preserve structure
- **Prism**: Single partial focus, returns Maybe, represents optional data
- Use Traversal when you need multiple foci to exist together or want to collect from multiple locations

**Two Operation Modes:**

1. **Collection mode** (`to_list/2`): Collects whatever matches
   - Lens foci: Always contribute (or raise on violation)
   - Prism foci: Contribute if they match, skip if they don't
   - Returns list of matched values

2. **Enforcement mode** (`to_list_maybe/2`): All-or-nothing extraction
   - Lens foci: Always contribute (or raise on violation)
   - Prism foci: Must all match, or entire operation returns Nothing
   - Returns Maybe of list - enforces co-presence

**Key Behavior:**

- **Lens in traversal**: Uses `view!`, contributes value or raises KeyError
- **Prism in traversal**: Uses `preview`, contributes Just or Nothing
- **Order matters**: First focus in combine order is first in output
- **Empty traversal**: `combine([])` creates traversal with no foci (returns empty list)

## LLM Decision Guide: When to Use Traversals

**✅ Use Traversal when:**

- Extracting values from multiple locations at once
- Enforcing co-presence: "these fields must all exist together"
- Validating relationships between multiple foci
- Working with domain rules that span multiple fields
- Need structural requirements as first-class values
- User says: "all these fields", "both must exist", "validate together", "extract multiple", "check relationship between"

**❌ Use Lens when:**

- Working with single required field
- Need to update values in place
- Absence is always a bug
- User says: "update this field", "set the value", "modify in place"

**❌ Use Prism when:**

- Working with single optional field
- Need to select one variant from sum types
- Absence is normal for that single field
- User says: "optional field", "might not have", "only if present"

**⚡ Traversal Strategy Decision:**

- **Simple multi-focus**: `Traversal.combine([Lens.key(:name), Lens.key(:age)])` for required fields
- **Mixed required/optional**: `Traversal.combine([Lens.key(:id), Prism.key(:email)])` mix lens and prism
- **Nested paths**: Combine composed optics: `Traversal.combine([Lens.path([:user, :name]), Lens.path([:user, :age])])`
- **Type-filtered**: Use prism composition: `Traversal.combine([item_lens, Prism.path([:payment, CreditCard, :amount])])`
- **First-match semantics**: Use `preview/2` when you need first successful focus
- **Existence check**: Use `has/2` when you just need boolean "does any match?"

**⚙️ Function Choice Guide:**

- **Collect matches**: `to_list/2` - get all values that match (lens foci always included, prism foci if they match)
- **Enforce co-presence**: `to_list_maybe/2` - all foci must succeed or get Nothing
- **First match**: `preview/2` - returns first matching focus as Maybe
- **Boolean check**: `has/2` - returns true if at least one focus matches
- **Build traversal**: `combine/1` - takes list of Lens/Prism optics

## LLM Context Clues

**User language → Traversal patterns:**

- "extract name and age" → `Traversal.combine([Lens.key(:name), Lens.key(:age)])` then `to_list/2`
- "both item and payment must exist" → `Traversal.combine([item_lens, payment_prism])` then `to_list_maybe/2`
- "validate amounts match" → Use traversal with `to_list_maybe/2` then guard in Maybe DSL
- "get first available contact" → `Traversal.combine([Prism.key(:email), Prism.key(:phone)])` then `preview/2`
- "check if any exist" → Build traversal then use `has/2`
- "collect all matching fields" → Build traversal then use `to_list/2`
- "require all fields present together" → Build traversal then use `to_list_maybe/2`
- "these fields are related" → Build traversal, extract with `to_list_maybe/2`, validate relationship

## Quick Reference

- Use `combine/1` to build traversal from list of Lens/Prism optics
- Use `to_list/2` to collect whatever matches (lens foci always, prism foci if they match)
- Use `to_list_maybe/2` for all-or-nothing extraction (enforces co-presence)
- Use `preview/2` to get first matching focus (in combine order)
- Use `has/2` for boolean check (returns true if any focus matches)
- **CRITICAL**: Lens foci raise on violation in ALL operations
- **CRITICAL**: Prism foci in `to_list/2` are skipped if they don't match
- **CRITICAL**: Prism foci in `to_list_maybe/2` cause entire operation to return Nothing if they don't match
- Order matters: foci are processed in combine order
- Empty traversal `combine([])` has no foci, returns empty list
- Traversals are first-class values - pass them around, compose them, test them
- Use with Maybe DSL: `to_list_maybe/2` returns Maybe, perfect for `bind` and `guard`
- Collection vs enforcement: choose based on whether absence of some foci is acceptable

## Overview

`Funx.Optics.Traversal` provides a multi-focus optic for targeting multiple locations in a data structure as a single operation.

**A Traversal is rarely used to test each element independently. Its real power is collecting multiple related foci so a single rule can relate them to each other.**

Use Traversal for:

- **Relating multiple foci to each other** (e.g., "refund matches charge amount")
- Enforcing structural requirements: "these fields must all exist together"
- Validating relationships between multiple values
- Collecting from multiple locations for comparison or aggregation
- Making structural dependencies first-class data

**Key insight**: Traversals serve two purposes:
1. **Collection mode** (`to_list/2`): Collect whatever foci exist (partial information, skips missing Prism foci)
2. **Enforcement mode** (`to_list_maybe/2`): Require all foci to exist (all-or-nothing, returns Nothing if any Prism focus missing)

The difference between these modes lets you express both "collect what you can" and "all or nothing" semantics.

## Constructor

### `combine/1` - Build Multi-Focus Traversal

Creates a traversal from a list of lenses and prisms:

```elixir
alias Funx.Optics.{Lens, Prism, Traversal}

# Simple traversal with two lenses
t1 = Traversal.combine([Lens.key(:name), Lens.key(:age)])

# Mixed lens and prism
t2 = Traversal.combine([
  Lens.key(:id),
  Prism.key(:email)
])

# With composed optics
user_name = Lens.path([:user, :name])
user_age = Lens.path([:user, :age])
t3 = Traversal.combine([user_name, user_age])

# Empty traversal (no foci)
t4 = Traversal.combine([])

# Type-filtered with prism composition
item_amount = Lens.path([:item, :amount])
cc_amount = Prism.path([:payment, CreditCard, :amount])
t5 = Traversal.combine([item_amount, cc_amount])
```

**Returns**: A traversal that targets all provided foci

## Core Operations

### `to_list/2` - Collect Matching Values

Extracts values from lens foci and any prism foci that match:

```elixir
user = %{name: "Alice", age: 30, email: "alice@example.com"}

# All lenses - all contribute
t1 = Traversal.combine([Lens.key(:name), Lens.key(:age)])
Traversal.to_list(user, t1)
#=> ["Alice", 30]

# Mixed - lens always included, prism if matches
t2 = Traversal.combine([Lens.key(:name), Prism.key(:email)])
Traversal.to_list(user, t2)
#=> ["Alice", "alice@example.com"]

incomplete = %{name: "Bob", age: 25}
Traversal.to_list(incomplete, t2)
#=> ["Bob"]  # email prism skipped

# Lens violation raises
Traversal.to_list(%{age: 30}, t1)
#=> ** (KeyError) key :name not found in: %{age: 30}
```

**Returns**: List of values (lens foci always included, prism foci if they match)

**Use when**: You want to collect whatever matches, absence of some foci is acceptable

### `to_list_maybe/2` - All-or-Nothing Extraction

Extracts values from all foci, returns Nothing if any prism doesn't match:

```elixir
user = %{name: "Alice", email: "alice@example.com"}

# All prisms match - returns Just
t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
Traversal.to_list_maybe(user, t)
#=> Just(["Alice", "alice@example.com"])

# One prism doesn't match - returns Nothing
incomplete = %{name: "Bob"}
Traversal.to_list_maybe(incomplete, t)
#=> Nothing

# Mixed with lens
t2 = Traversal.combine([Lens.key(:id), Prism.key(:email)])
Traversal.to_list_maybe(%{id: 1, email: "alice@example.com"}, t2)
#=> Just([1, "alice@example.com"])

# Lens violation still raises
Traversal.to_list_maybe(%{email: "alice@example.com"}, t2)
#=> ** (KeyError) key :id not found in: %{email: "alice@example.com"}
```

**Returns**: `Just(list)` when every focus succeeds, `Nothing` if any prism doesn't match

**Use when**: You need all foci to exist together (enforcing co-presence)

### `preview/2` - First Matching Focus

Returns the first matching focus in combine order:

```elixir
user = %{name: "Alice", email: "alice@example.com", phone: "555-1234"}

# Returns first match
t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
Traversal.preview(user, t)
#=> Just("alice@example.com")  # email is first

# Order matters
t2 = Traversal.combine([Prism.key(:phone), Prism.key(:email)])
Traversal.preview(user, t2)
#=> Just("555-1234")  # phone is first now

# Skips Nothing, returns first Just
incomplete = %{name: "Bob", phone: "555-5678"}
Traversal.preview(incomplete, t)
#=> Just("555-5678")  # email is Nothing, phone is Just

# Nothing when no foci match
Traversal.preview(%{name: "Carol"}, t)
#=> Nothing

# Lens raises on violation
t3 = Traversal.combine([Lens.key(:id), Prism.key(:email)])
Traversal.preview(%{email: "alice@example.com"}, t3)
#=> ** (KeyError) key :id not found in: %{email: "alice@example.com"}
```

**Returns**: `Just(value)` for first matching focus, `Nothing` if none match

**Use when**: You need first-available semantics (email OR phone OR ...)

### `has/2` - Boolean Check

Returns true if at least one focus matches (query only, never returns data):

```elixir
user = %{name: "Alice", email: "alice@example.com"}

t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])

# Has email
Traversal.has(user, t)
#=> true

# No email or phone
Traversal.has(%{name: "Bob"}, t)
#=> false

# Empty traversal always false
empty = Traversal.combine([])
Traversal.has(user, empty)
#=> false
```

**Returns**: Boolean (true if any focus matches, false otherwise)

**Use when**: You only need existence check, not the actual values

## Working with Maybe DSL

`to_list_maybe/2` returns Maybe, perfect for validation pipelines:

```elixir
use Funx.Monad.Maybe

defmodule Item, do: defstruct [:name, :amount]
defmodule CreditCard, do: defstruct [:name, :amount]
defmodule Transaction, do: defstruct [:item, :payment]

# Build traversal for related foci
item_amount = Lens.path([:item, :amount])
cc_amount = Prism.path([:payment, CreditCard, :amount])
amounts_trav = Traversal.combine([item_amount, cc_amount])

# Validation function
defmodule ValidateAmounts do
  def run_maybe([item_amount, payment_amount], _opts, _env) do
    item_amount == payment_amount
  end
end

# Use in Maybe DSL pipeline
transaction = %Transaction{
  item: %Item{name: "Camera", amount: 500},
  payment: %CreditCard{name: "Alice", amount: 500}
}

maybe transaction do
  bind Traversal.to_list_maybe(amounts_trav)  # Extract foci
  guard ValidateAmounts                        # Validate relationship
end
#=> Just([500, 500])

# Wrong payment type fails at extraction
check_transaction = %Transaction{
  item: %Item{name: "Lens", amount: 300},
  payment: %Check{name: "Bob", amount: 300}
}

maybe check_transaction do
  bind Traversal.to_list_maybe(amounts_trav)
  guard ValidateAmounts
end
#=> Nothing  # CreditCard prism didn't match

# Mismatched amounts fail at validation
invalid = %Transaction{
  item: %Item{name: "Camera", amount: 500},
  payment: %CreditCard{name: "Alice", amount: 400}
}

maybe invalid do
  bind Traversal.to_list_maybe(amounts_trav)
  guard ValidateAmounts
end
#=> Nothing  # Guard failed
```

**Pattern**: Extract related foci with traversal, then validate their relationship

## Common Patterns

### Extracting Multiple Required Fields

```elixir
# Get multiple required fields at once
user = %{name: "Alice", age: 30, email: "alice@example.com"}
t = Traversal.combine([Lens.key(:name), Lens.key(:age)])

Traversal.to_list(user, t)
#=> ["Alice", 30]

# Destructure in pattern match
case Traversal.to_list(user, t) do
  [name, age] -> "#{name} is #{age} years old"
end
#=> "Alice is 30 years old"
```

### Collecting from Mixed Required/Optional Fields

```elixir
# Required ID, optional email
t = Traversal.combine([Lens.key(:id), Prism.key(:email)])

complete = %{id: 1, name: "Alice", email: "alice@example.com"}
Traversal.to_list(complete, t)
#=> [1, "alice@example.com"]

incomplete = %{id: 2, name: "Bob"}
Traversal.to_list(incomplete, t)
#=> [2]  # email skipped
```

### Enforcing Co-Presence

```elixir
# Both fields must exist together
t = Traversal.combine([Prism.key(:lat), Prism.key(:lon)])

valid_location = %{lat: 37.7749, lon: -122.4194, city: "SF"}
Traversal.to_list_maybe(valid_location, t)
#=> Just([37.7749, -122.4194])

incomplete_location = %{city: "SF"}
Traversal.to_list_maybe(incomplete_location, t)
#=> Nothing  # Both must exist together
```

### First-Available Contact Method

```elixir
# Try email, then phone, then address
contact_trav = Traversal.combine([
  Prism.key(:email),
  Prism.key(:phone),
  Prism.key(:address)
])

user1 = %{name: "Alice", email: "alice@example.com"}
Traversal.preview(user1, contact_trav)
#=> Just("alice@example.com")

user2 = %{name: "Bob", phone: "555-1234"}
Traversal.preview(user2, contact_trav)
#=> Just("555-1234")

user3 = %{name: "Carol"}
Traversal.preview(user3, contact_trav)
#=> Nothing
```

### Domain Validation with Traversal

```elixir
# Validate relationship between extracted values
age_height_trav = Traversal.combine([
  Lens.key(:age),
  Lens.key(:height_cm)
])

defmodule ValidateAgeHeight do
  def run_maybe([age, height], _opts, _env) do
    # Children (< 18) should be shorter than 180cm
    age >= 18 or height < 180
  end
end

person = %{name: "Alice", age: 16, height_cm: 165}

maybe person do
  bind Traversal.to_list_maybe(age_height_trav)
  guard ValidateAgeHeight
end
#=> Just([16, 165])  # Valid
```

### Collecting from List of Structures

```elixir
# Extract amounts from all credit card transactions
transactions = [
  %Transaction{payment: %CreditCard{amount: 100}},
  %Transaction{payment: %Check{amount: 200}},
  %Transaction{payment: %CreditCard{amount: 150}}
]

cc_amount_trav = Traversal.combine([
  Prism.path([:payment, CreditCard, :amount])
])

# Collect all matching amounts
transactions
|> Enum.flat_map(&Traversal.to_list(&1, cc_amount_trav))
#=> [100, 150]  # Check transaction skipped

# Or use Maybe operations
alias Funx.Monad.Maybe

transactions
|> Maybe.concat_map(&Traversal.to_list_maybe(&1, cc_amount_trav))
#=> [100, 150]
```

## Anti-Patterns

**❌ Don't use traversal for single focus:**

```elixir
# BAD: Single focus doesn't need traversal
t = Traversal.combine([Lens.key(:name)])
Traversal.to_list(user, t)

# GOOD: Use Lens directly
Lens.view!(user, Lens.key(:name))
```

**❌ Don't confuse collection and enforcement modes:**

```elixir
# BAD: Using to_list when you need all-or-nothing
t = Traversal.combine([Prism.key(:lat), Prism.key(:lon)])
result = Traversal.to_list(location, t)
# result might be [lat] or [lon] or [lat, lon]

# GOOD: Use to_list_maybe for co-presence
case Traversal.to_list_maybe(location, t) do
  Just([lat, lon]) -> {:ok, {lat, lon}}
  Nothing -> {:error, :incomplete_location}
end
```

**❌ Don't forget lens raises:**

```elixir
# BAD: Assuming lens failure returns Nothing
t = Traversal.combine([Lens.key(:id), Prism.key(:email)])
# If :id missing, this raises, doesn't return Nothing!

# GOOD: Use prism if field is optional
t = Traversal.combine([Prism.key(:id), Prism.key(:email)])
# Now missing :id returns Nothing
```

**❌ Don't ignore combine order:**

```elixir
# BAD: Expecting arbitrary order
t = Traversal.combine([Lens.key(:age), Lens.key(:name)])
[name, age] = Traversal.to_list(user, t)
# WRONG: First is age, second is name!

# GOOD: Destructure in combine order
[age, name] = Traversal.to_list(user, t)
```

**✅ Do use traversal for multiple foci:**

```elixir
# GOOD: Multiple foci that relate to each other
t = Traversal.combine([item_amount, payment_amount])
maybe transaction do
  bind Traversal.to_list_maybe(t)
  guard ValidateAmountsMatch
end
```

**✅ Do choose correct mode:**

```elixir
# GOOD: Collection mode when some can be missing
contact_methods = Traversal.combine([
  Prism.key(:email),
  Prism.key(:phone)
])
contacts = Traversal.to_list(user, contact_methods)
# Get whatever is available

# GOOD: Enforcement mode when all required together
coordinates = Traversal.combine([
  Prism.key(:lat),
  Prism.key(:lon)
])
case Traversal.to_list_maybe(location, coordinates) do
  Just([lat, lon]) -> # Both present
  Nothing -> # Either missing
end
```

**✅ Do use prism for optional focus:**

```elixir
# GOOD: Prism for optional, lens for required
t = Traversal.combine([
  Lens.key(:id),        # Required
  Prism.key(:email)     # Optional
])
```

**✅ Do respect combine order:**

```elixir
# GOOD: Build traversal in desired output order
user_info = Traversal.combine([
  Lens.key(:name),    # First
  Lens.key(:age),     # Second
  Prism.key(:email)   # Third
])
```

## Implementation Note

A traversal is a struct containing a list of optics:

```elixir
%Traversal{foci: [lens1, prism1, lens2]}
```

Operations like `to_list/2` and `to_list_maybe/2` iterate over the foci list, applying each optic to the structure and collecting results according to the operation's semantics.

The difference between modes:
- `to_list/2` uses `Maybe.concat_map` (collects Justs, skips Nothings)
- `to_list_maybe/2` uses `Maybe.traverse` (all must succeed or Nothing)

This compositionality ensures traversal behavior is predictable and lawful.
