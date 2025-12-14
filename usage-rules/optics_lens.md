# `Funx.Optics.Lens` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Lens**: A total optic for focusing on a part of a data structure

- **Total access**: The focus ALWAYS exists (raises `KeyError` if missing)
- **Three operations**: `view!/2` (extract), `set!/3` (update), `over!/3` (transform)
- **Safe variants**: `view/3`, `set/4`, `over/4` (return Either or tuples instead of raising)
- **Lawful**: Must satisfy get-put, put-get, and put-put laws
- **Compositional**: Lenses compose via `compose/2` or `concat/1`
- **Structure-preserving**: Updates maintain all other fields and struct types

**Lens vs Prism:**

- **Lens**: Total access, raises on missing keys, updates preserve structure
- **Prism**: Partial access, returns Maybe, reconstructs minimal structure
- Use Lens when absence is a bug; use Prism when absence is normal

**Lens Laws:**

1. **Get-Put**: `set!(s, lens, view!(s, lens)) = s` (viewing then setting changes nothing)
2. **Put-Get**: `view!(set!(s, lens, a), lens) = a` (setting then viewing returns what was set)
3. **Put-Put**: `set!(set!(s, lens, a), lens, b) = set!(s, lens, b)` (last set wins)

**Error Handling Modes** (for safe operations):

- `:either` (default) - Returns `Right(value)` or `Left(exception)`
- `:tuple` - Returns `{:ok, value}` or `{:error, exception}`
- `:raise` - Raises exceptions (behaves like `!` versions)

**Important**: Lenses enforce totality symmetrically. If the focus might not exist, use a Prism instead.

## LLM Decision Guide: When to Use Lenses

**✅ Use Lens when:**

- Field should always exist (required fields, schema-enforced data)
- Absence would indicate a bug
- Need to update while preserving rest of structure
- Working with strongly-typed domain models
- Struct types must be maintained
- User says: "update field", "modify", "change", "set value", "increment"

**❌ Use Prism when:**

- Field is optional or nullable
- Absence is normal and expected
- Working with variants or sum types
- Filtering data based on predicates
- User says: "optional", "might not have", "if exists", "filter"

**⚡ Lens Strategy Decision:**

- **Single field access**: `Lens.key(:name)` for maps/structs
- **Nested paths**: `Lens.path([:user, :profile, :email])` for multi-level access
- **Extract value**: `view!/2` raises on error, `view/3` for safe Either/tuple return
- **Update value**: `set!/3` raises on error, `set/4` for safe return
- **Transform value**: `over!/3` applies function, `over/4` for safe return
- **Compose lenses**: `compose/2` for two, `concat/1` for multiple
- **Custom lenses**: `make/2` with viewer and updater functions

**⚙️ Function Choice Guide:**

- **Extract field value**: `view!/2` (raises) or `view/3` (safe)
- **Replace field value**: `set!/3` (raises) or `set/4` (safe)
- **Transform field value**: `over!/3` (raises) or `over/4` (safe)
- **Nested access**: Use `path/1` or compose with `compose/2`
- **Chain operations**: Compose lenses, then use single operation
- **Error handling**: Use safe variants with `:either` or `:tuple` mode

## LLM Context Clues

**User language → Lens patterns:**

- "update user's email" → `Lens.set!(user, Lens.key(:email), new_email)`
- "increment score" → `Lens.over!(data, Lens.path([:stats, :score]), &(&1 + 1))`
- "change nested field" → `Lens.path([:outer, :inner, :field])`
- "modify profile name" → `Lens.set!(user, Lens.path([:profile, :name]), "New Name")`
- "get user age" → `Lens.view!(user, Lens.key(:age))`
- "safely read config" → `Lens.view(config, Lens.key(:timeout), as: :either)`
- "transform all caps" → `Lens.over!(data, Lens.key(:text), &String.upcase/1)`

## Quick Reference

- Use `view!/2` to extract - raises `KeyError` if missing
- Use `set!/3` to replace - raises `KeyError` if missing
- Use `over!/3` to transform - raises `KeyError` if missing
- Safe versions (`view/3`, `set/4`, `over/4`) return Either or tuples
- Chain with `compose/2` or `concat/1`
- Path shorthand: `path([:a, :b, :c])` = `concat([key(:a), key(:b), key(:c)])`
- Lenses preserve structure type (structs stay structs)
- **IMPORTANT**: Only use Lens when focus must exist - absence is a bug
- For optional fields, use Prism instead
- Import neither - use fully qualified names: `Lens.view!/2`, `Lens.set!/3`

## Overview

`Funx.Optics.Lens` provides lawful total optics for focusing on required parts of data structures.

Use Lens for:

- Required fields that should always exist
- Schema-enforced data (database columns with NOT NULL)
- Updating values while preserving structure
- Strongly-typed domain models
- Nested field access where all intermediate paths must exist

**Key insight**: Lenses are *total* - they assume the focus always exists. If accessing or updating fails, it raises `KeyError`. This enforces correctness: absence indicates a bug, not normal program flow.

Unlike Prism (which returns Maybe for partial access), Lens either succeeds completely or fails loudly.

## Constructors

### `key/1` - Focus on Required Map/Struct Key

Creates a lens focusing on a single key that must exist:

```elixir
alias Funx.Optics.Lens

# Create lens for :name key
name_lens = Lens.key(:name)

# View extracts value (raises if missing)
Lens.view!(%{name: "Alice", age: 30}, name_lens)
#=> "Alice"

# Set updates value (raises if key doesn't exist)
Lens.set!(%{name: "Alice", age: 30}, name_lens, "Bob")
#=> %{name: "Bob", age: 30}

# Raises on missing key
Lens.view!(%{age: 30}, name_lens)
#=> ** (KeyError) key :name not found in: %{age: 30}
```

**Works with:**

- Atom keys: `Lens.key(:name)`
- String keys: `Lens.key("name")`
- Structs (preserves type): `Lens.set!(%User{name: "Alice"}, Lens.key(:name), "Bob")`

**Contract**: Key MUST exist. If it might not, use `Prism.key/1` instead.

### `path/1` - Focus on Nested Required Path

Creates a lens for multi-level access where all keys must exist:

```elixir
# Nested path through required fields
email_lens = Lens.path([:user, :profile, :email])

data = %{
  user: %{
    profile: %{
      email: "alice@example.com",
      age: 30
    }
  }
}

# View nested value
Lens.view!(data, email_lens)
#=> "alice@example.com"

# Set nested value (preserves all other structure)
Lens.set!(data, email_lens, "bob@example.com")
#=> %{
#     user: %{
#       profile: %{
#         email: "bob@example.com",
#         age: 30  # preserved!
#       }
#     }
#   }

# Raises if any intermediate key missing
Lens.view!(%{user: %{}}, email_lens)
#=> ** (KeyError) key :profile not found in: %{}
```

**Implementation**: `path(keys)` = `concat(Enum.map(keys, &key/1))`

**Contract**: ALL keys in path MUST exist. If any might be missing, use `Prism.path/1` instead.

### `make/2` - Custom Lenses

Creates a lens from viewer and updater functions:

```elixir
# Lens focusing on first element of tuple
first_lens = Lens.make(
  fn {a, _b} -> a end,           # viewer
  fn {_a, b}, new_a -> {new_a, b} end  # updater
)

Lens.view!({1, 2}, first_lens)
#=> 1

Lens.set!({1, 2}, first_lens, 99)
#=> {99, 2}
```

**IMPORTANT**: You are responsible for ensuring viewer/updater obey lens laws.

## Core Operations (Raise on Error)

### `view!/2` - Extract Focus

Extracts the focused part, raising on failure:

```elixir
user = %{name: "Alice", email: "alice@example.com"}
name_lens = Lens.key(:name)

Lens.view!(user, name_lens)
#=> "Alice"

# Raises if key missing
Lens.view!(%{email: "alice@example.com"}, name_lens)
#=> ** (KeyError) key :name not found
```

**Signature**: `view!(structure, lens) :: value`

**Raises**: `KeyError` if focus doesn't exist

### `set!/3` - Update Focus

Updates the focused part, preserving all other structure:

```elixir
user = %{name: "Alice", age: 30, email: "alice@example.com"}
name_lens = Lens.key(:name)

Lens.set!(user, name_lens, "Bob")
#=> %{name: "Bob", age: 30, email: "alice@example.com"}

# Preserves struct types
defmodule User, do: defstruct [:name, :age]
u = %User{name: "Alice", age: 30}

Lens.set!(u, name_lens, "Bob")
#=> %User{name: "Bob", age: 30}  # Still a User struct!
```

**Signature**: `set!(structure, lens, new_value) :: updated_structure`

**Raises**: `KeyError` if focus doesn't exist

### `over!/3` - Transform Focus

Applies a function to the focused part:

```elixir
score = %{points: 100}
points_lens = Lens.key(:points)

# Increment
Lens.over!(score, points_lens, &(&1 + 10))
#=> %{points: 110}

# Double
Lens.over!(score, points_lens, &(&1 * 2))
#=> %{points: 200}

# Works with nested lenses
stats = %{user: %{score: %{points: 100}}}
points_path = Lens.path([:user, :score, :points])

Lens.over!(stats, points_path, &(&1 + 50))
#=> %{user: %{score: %{points: 150}}}
```

**Signature**: `over!(structure, lens, transform_fn) :: updated_structure`

**Implementation**: `over!(s, lens, f) = set!(s, lens, f.(view!(s, lens)))`

**Raises**: `KeyError` if focus doesn't exist

## Safe Operations (Return Either or Tuples)

All safe operations accept optional `as:` parameter for error handling mode.

### `view/3` - Safe Extract

Safe version returning Either or tuple instead of raising:

```elixir
alias Funx.Monad.Either

user = %{name: "Alice"}
name_lens = Lens.key(:name)

# Default: returns Either
Lens.view(user, name_lens)
#=> %Either.Right{right: "Alice"}

Lens.view(%{age: 30}, name_lens)
#=> %Either.Left{left: %KeyError{key: :name, term: %{age: 30}}}

# Tuple mode
Lens.view(user, name_lens, as: :tuple)
#=> {:ok, "Alice"}

Lens.view(%{age: 30}, name_lens, as: :tuple)
#=> {:error, %KeyError{...}}

# Raise mode (behaves like view!/2)
Lens.view(user, name_lens, as: :raise)
#=> "Alice"
```

**Modes:**

- `:either` (default) - `Right(value)` or `Left(exception)`
- `:tuple` - `{:ok, value}` or `{:error, exception}`
- `:raise` - raises exceptions like `view!/2`

### `set/4` - Safe Update

Safe version of set!/3:

```elixir
user = %{name: "Alice", age: 30}
name_lens = Lens.key(:name)

# Default: Either
Lens.set(user, name_lens, "Bob")
#=> %Either.Right{right: %{name: "Bob", age: 30}}

Lens.set(%{age: 30}, name_lens, "Bob")
#=> %Either.Left{left: %KeyError{...}}

# Tuple mode
Lens.set(user, name_lens, "Bob", as: :tuple)
#=> {:ok, %{name: "Bob", age: 30}}

# Raise mode
Lens.set(user, name_lens, "Bob", as: :raise)
#=> %{name: "Bob", age: 30}
```

### `over/4` - Safe Transform

Safe version of over!/3:

```elixir
score = %{points: 100}
points_lens = Lens.key(:points)

# Default: Either
Lens.over(score, points_lens, &(&1 + 10))
#=> %Either.Right{right: %{points: 110}}

Lens.over(%{}, points_lens, &(&1 + 10))
#=> %Either.Left{left: %KeyError{...}}

# Tuple mode
Lens.over(score, points_lens, &(&1 * 2), as: :tuple)
#=> {:ok, %{points: 200}}
```

**Note**: Safe operations catch ALL exceptions, not just `KeyError`. Any exception from user functions in `over/4` will be caught and wrapped.

## Composition

### `compose/2` - Compose Two Lenses

Composes two lenses sequentially:

```elixir
# Individual lenses
user_lens = Lens.key(:user)
profile_lens = Lens.key(:profile)
name_lens = Lens.key(:name)

# Compose outer with inner
user_profile = Lens.compose(user_lens, profile_lens)

data = %{
  user: %{
    profile: %{name: "Alice", age: 30}
  }
}

Lens.view!(data, user_profile)
#=> %{name: "Alice", age: 30}

# Chain compositions
user_profile_name = Lens.compose(user_profile, name_lens)

Lens.view!(data, user_profile_name)
#=> "Alice"

Lens.set!(data, user_profile_name, "Bob")
#=> %{user: %{profile: %{name: "Bob", age: 30}}}
```

**Note**: Composition is associative: `compose(compose(a, b), c) = compose(a, compose(b, c))`

### `concat/1` - Compose Multiple Lenses

Composes a list of lenses:

```elixir
# These are equivalent:
path_lens = Lens.concat([
  Lens.key(:user),
  Lens.key(:profile),
  Lens.key(:name)
])

# Same as:
path_lens = Lens.path([:user, :profile, :name])

data = %{user: %{profile: %{name: "Alice"}}}

Lens.view!(data, path_lens)
#=> "Alice"

Lens.over!(data, path_lens, &String.upcase/1)
#=> %{user: %{profile: %{name: "ALICE"}}}
```

**Implementation**: `path/1` is implemented as `concat(Enum.map(keys, &key/1))`

## Working with Either Results

Safe operations return Either by default, so use Either operations:

```elixir
import Funx.Monad
alias Funx.Monad.Either

config = %{database: %{timeout: 5000}}
timeout_lens = Lens.path([:database, :timeout])

# Extract with Either
config
|> Lens.view(timeout_lens)
|> Either.get_or_else(3000)
#=> 5000

# Chain with Either operations
config
|> Lens.view(timeout_lens)
|> map(&(&1 * 2))  # doubles if successful
#=> Right(10000)

# Pattern match on result
case Lens.view(config, timeout_lens) do
  %Either.Right{right: timeout} ->
    IO.puts("Timeout: #{timeout}")
  %Either.Left{left: error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

**Or use tuple mode for standard Elixir patterns:**

```elixir
case Lens.view(config, timeout_lens, as: :tuple) do
  {:ok, timeout} -> timeout
  {:error, _} -> 3000
end
```

## Common Patterns

### Update Nested Field

```elixir
user = %{
  profile: %{
    settings: %{
      theme: "dark",
      notifications: true
    }
  }
}

theme_lens = Lens.path([:profile, :settings, :theme])

Lens.set!(user, theme_lens, "light")
#=> %{profile: %{settings: %{theme: "light", notifications: true}}}
```

### Increment Counter

```elixir
stats = %{views: 100, likes: 50}
views_lens = Lens.key(:views)

Lens.over!(stats, views_lens, &(&1 + 1))
#=> %{views: 101, likes: 50}
```

### Transform String Field

```elixir
user = %{name: "alice", email: "alice@example.com"}
name_lens = Lens.key(:name)

Lens.over!(user, name_lens, &String.capitalize/1)
#=> %{name: "Alice", email: "alice@example.com"}
```

### Preserve Struct Types

```elixir
defmodule Account do
  defstruct [:balance, :owner]
end

account = %Account{balance: 1000, owner: "Alice"}
balance_lens = Lens.key(:balance)

# Struct type preserved!
Lens.set!(account, balance_lens, 2000)
#=> %Account{balance: 2000, owner: "Alice"}
```

### Safe Error Handling

```elixir
# Using Either
result = Lens.view(data, lens)

case result do
  %Either.Right{right: value} ->
    process(value)
  %Either.Left{left: error} ->
    log_error(error)
    use_default()
end

# Using tuple mode
case Lens.view(data, lens, as: :tuple) do
  {:ok, value} -> process(value)
  {:error, _} -> use_default()
end
```

### Pipeline Updates

```elixir
user
|> Lens.set!(name_lens, "Bob")
|> Lens.over!(age_lens, &(&1 + 1))
|> Lens.set!(email_lens, "bob@example.com")
```

## Anti-Patterns

**❌ Don't use Lens for optional fields:**

```elixir
# BAD: Field might not exist
optional_email = Lens.key(:email)
Lens.view!(user, optional_email)  # Raises if missing!

# GOOD: Use Prism instead
alias Funx.Optics.Prism
optional_email = Prism.key(:email)
Prism.preview(user, optional_email)  # Returns Maybe
```

**❌ Don't ignore safe operation errors:**

```elixir
# BAD: Not handling error case
%Either.Right{right: value} = Lens.view(data, lens)  # Crashes on error!

# GOOD: Handle both cases
case Lens.view(data, lens) do
  %Either.Right{right: value} -> use(value)
  %Either.Left{left: _error} -> use_default()
end
```

**❌ Don't use path for optional intermediate values:**

```elixir
# BAD: :profile might not exist
lens = Lens.path([:profile, :email])  # Raises if profile missing!

# GOOD: Use Prism.path if any key might be missing
lens = Prism.path([:profile, :email])  # Returns Nothing if missing
```

**✅ Do use Lens for required fields:**

```elixir
# GOOD: ID should always exist
id_lens = Lens.key(:id)
Lens.view!(user, id_lens)  # Correct to raise if missing
```

**✅ Do use safe operations when error handling matters:**

```elixir
# GOOD: Explicit error handling
case Lens.view(config, timeout_lens, as: :tuple) do
  {:ok, timeout} -> timeout
  {:error, _} -> default_timeout
end
```

**✅ Do compose lenses for nested access:**

```elixir
# GOOD: Clear, composable
user_email = Lens.compose(
  Lens.key(:user),
  Lens.key(:email)
)

# Or use path shorthand
user_email = Lens.path([:user, :email])
```

## Implementation Note

Lenses are lawful and total:

- **Total**: Focus must always exist (enforced by raising `KeyError`)
- **Lawful**: Satisfies get-put, put-get, and put-put laws
- **Compositional**: `compose/2` and `concat/1` preserve laws
- **Structure-preserving**: Updates maintain all other fields and types

The `key/1` lens uses `Map.fetch!/2` for viewing and `Map.replace!/3` for updating, ensuring symmetric totality enforcement.
