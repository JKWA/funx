# `Funx.Optics.Iso` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Iso (Isomorphism)**: A total, bidirectional, lossless optic for converting between two equivalent representations

- **Bidirectional**: Two inverse functions (view and review) that convert in both directions
- **Lossless**: Round-trips preserve all information - no data is lost
- **Total**: Both transformations always succeed (no Maybe/Either)
- **Lawful**: Must satisfy strict round-trip laws
- **Compositional**: Isos compose naturally via `compose/2` or `compose/1`
- **Most powerful optic**: Can be used as a Lens or Prism

**Iso vs Lens vs Prism:**

- **Iso**: Bidirectional lossless conversion, total in both directions
- **Lens**: One-way view with update, total access, preserves structure
- **Prism**: Partial access (may fail), reconstructs minimal structure
- Use Iso when you have true equivalence between representations

**Iso Laws:**

1. **Review-View**: `review(view(s, iso), iso) = s` (forward then back returns original)
2. **View-Review**: `view(review(a, iso), iso) = a` (back then forward returns original)

These laws ensure the transformation is truly lossless and bidirectional.

**Key Operations:**

- `view/2` - Apply forward transformation (s -> a)
- `review/2` - Apply backward transformation (a -> s)
- `over/3` - Transform the viewed side (view, apply function, review)
- `under/3` - Transform the reviewed side (review, apply function, view)
- `from/1` - Reverse the iso's direction

**Important Constraints:**

- Both functions must be true inverses - no runtime checks enforce this
- If transformations can fail, you don't have an iso (use Prism instead)
- Contract violations crash immediately - there are no safe variants
- Isos are structure-agnostic - they only care about information preservation

## LLM Decision Guide: When to Use Isos

**✅ Use Iso when:**

- Converting between equivalent representations (String ↔ CharList)
- Type conversions that preserve information (Celsius ↔ Fahrenheit)
- Format transformations (Map ↔ Struct with all same fields)
- Encoding/decoding (Base64 ↔ Binary)
- Both directions always succeed and preserve all data
- User says: "convert", "transform", "encode/decode", "format", "bidirectional"

**❌ Use Lens when:**

- Need to focus on part of a structure
- Updates should preserve the rest of the structure
- Only need one-way access with updates
- User says: "update field", "modify", "set value"

**❌ Use Prism when:**

- Transformation might fail (parsing can fail)
- Access is partial or optional
- Information might be lost
- User says: "parse", "extract if present", "optional"

**⚡ Iso Strategy Decision:**

- **Type conversions**: String ↔ Integer, List ↔ Vector
- **Unit conversions**: Celsius ↔ Fahrenheit, Miles ↔ Kilometers
- **Format conversions**: Map ↔ Struct, JSON ↔ Domain type
- **Encoding**: String ↔ Base64, Binary ↔ Hex
- **Composition**: Chain multiple isos for complex transformations
- **Custom isos**: `Iso.make/2` for domain-specific conversions

**⚙️ Function Choice Guide:**

- **Convert forward**: `view/2` - Transform s to a
- **Convert backward**: `review/2` - Transform a to s
- **Transform viewed**: `over/3` - Apply function to viewed value
- **Transform reviewed**: `under/3` - Apply function to reviewed value
- **Reverse direction**: `from/1` - Swap view and review
- **Compose isos**: `compose/2` for two, `compose/1` for list
- **As lens**: `as_lens/1` - Use iso as a lens
- **As prism**: `as_prism/1` - Use iso as a prism

## LLM Context Clues

**User language → Iso patterns:**

- "convert string to integer" → `Iso.make(&String.to_integer/1, &Integer.to_string/1)`
- "celsius to fahrenheit" → `Iso.make(fn c -> c * 9/5 + 32 end, fn f -> (f - 32) * 5/9 end)`
- "encode to base64" → `Iso.make(&Base.encode64/1, &Base.decode64!/1)`
- "transform between formats" → Create custom iso with `Iso.make/2`
- "chain conversions" → `Iso.compose([iso1, iso2, iso3])`
- "reverse the transformation" → `Iso.from(iso)`
- "use as lens" → `Iso.as_lens(iso)`

## Quick Reference

- Use `view/2` for forward transformation (s -> a)
- Use `review/2` for backward transformation (a -> s)
- Use `over/3` to transform the viewed side
- Use `under/3` to transform the reviewed side
- Use `from/1` to reverse an iso's direction
- Chain isos with `compose/2` or `compose/1`
- Convert to lens/prism with `as_lens/1` or `as_prism/1`
- **CRITICAL**: Both transformations must be total and lossless
- Identity iso: `Iso.identity()` - transforms nothing

## Overview

`Funx.Optics.Iso` provides lawful isomorphisms for bidirectional, lossless transformations between equivalent representations. Isos are the most powerful optic - they can be used as lenses or prisms because they guarantee total access in both directions.

The module enforces strict round-trip laws ensuring that transforming forward then backward (or vice versa) always returns the original value. This makes isos perfect for type conversions, format transformations, and encoding/decoding where no information is lost.

## Composition Rules

| Function       | Type Signature                          | Purpose                                           |
| -------------- | --------------------------------------- | ------------------------------------------------- |
| `make/2`       | `(s -> a) -> (a -> s) -> Iso s a`       | Create custom iso from inverse functions          |
| `identity/0`   | `Iso a a`                               | Identity iso (no transformation)                  |
| `view/2`       | `s -> Iso s a -> a`                     | Apply forward transformation                      |
| `review/2`     | `a -> Iso s a -> s`                     | Apply backward transformation                     |
| `over/3`       | `s -> Iso s a -> (a -> a) -> s`         | Transform viewed value                            |
| `under/3`      | `a -> Iso s a -> (s -> s) -> a`         | Transform reviewed value                          |
| `from/1`       | `Iso s a -> Iso a s`                    | Reverse iso direction                             |
| `compose/2`    | `Iso s a -> Iso a b -> Iso s b`         | Compose two isos sequentially                     |
| `compose/1`    | `[Iso] -> Iso`                          | Compose list of isos                              |
| `as_lens/1`    | `Iso s a -> Lens s a`                   | Convert iso to lens                               |
| `as_prism/1`   | `Iso s a -> Prism s a`                  | Convert iso to prism                              |

## Correct Usage Patterns

### Basic Type Conversion

```elixir
alias Funx.Optics.Iso

# String <-> Integer
string_int = Iso.make(
  fn s -> String.to_integer(s) end,
  fn i -> Integer.to_string(i) end
)

Iso.view("42", string_int)
# 42

Iso.review(42, string_int)
# "42"
```

### Unit Conversion

```elixir
# Celsius <-> Fahrenheit
temp_iso = Iso.make(
  fn c -> c * 9 / 5 + 32 end,
  fn f -> (f - 32) * 5 / 9 end
)

Iso.view(0, temp_iso)
# 32.0

Iso.review(32, temp_iso)
# 0.0
```

### Format Conversion

```elixir
# Map <-> Struct (lossless if all fields present)
defmodule User do
  defstruct [:name, :email]
end

user_iso = Iso.make(
  fn %{name: n, email: e} -> %User{name: n, email: e} end,
  fn %User{name: n, email: e} -> %{name: n, email: e} end
)

Iso.view(%{name: "Alice", email: "alice@example.com"}, user_iso)
# %User{name: "Alice", email: "alice@example.com"}
```

### Composing Isos

```elixir
# String -> Integer -> Doubled Integer
string_int = Iso.make(
  &String.to_integer/1,
  &Integer.to_string/1
)

double = Iso.make(
  fn i -> i * 2 end,
  fn i -> div(i, 2) end
)

# Compose: String <-> Doubled Integer
string_doubled = Iso.compose(string_int, double)

Iso.view("21", string_doubled)
# 42

Iso.review(42, string_doubled)
# "21"
```

### Reversing Isos

```elixir
# Forward: Celsius -> Fahrenheit
forward = Iso.make(
  fn c -> c * 9 / 5 + 32 end,
  fn f -> (f - 32) * 5 / 9 end
)

# Reverse: Fahrenheit -> Celsius
backward = Iso.from(forward)

Iso.view(32, backward)
# 0.0
```

### Transforming Values

```elixir
string_int = Iso.make(
  &String.to_integer/1,
  &Integer.to_string/1
)

# Transform the int side (viewed)
Iso.over("10", string_int, fn i -> i * 5 end)
# "50"

# Transform the string side (reviewed)
Iso.under(100, string_int, fn s -> s <> "0" end)
# 1000
```

### Using Isos as Lenses

```elixir
# Every iso can be used as a lens
string_int = Iso.make(
  &String.to_integer/1,
  &Integer.to_string/1
)

lens = Iso.as_lens(string_int)

# Now use all lens operations
Lens.view("42", lens)
# 42

Lens.set("10", lens, 99)
# "99"
```

### Using Isos as Prisms

```elixir
# Every iso can be used as a prism
string_int_iso = Iso.make(
  &String.to_integer/1,
  &Integer.to_string/1
)

prism = Iso.as_prism(string_int_iso)

# Preview always succeeds (returns Just)
Prism.preview("42", prism)
# Just(42)
```

## Compositional Guidelines

### Iso Composition Order

When composing isos, think about the transformation pipeline:

```elixir
# Composition: outer then inner for view
# String -> Integer -> Doubled
composed = Iso.compose(string_to_int, doubler)

# For view: applies string_to_int first, then doubler
# For review: applies doubler first (backward), then string_to_int (backward)
```

### Monoid Structure

Isos form a monoid under composition:

```elixir
alias Funx.Monoid.Optics.IsoCompose
import Funx.Monoid.Utils

# Compose multiple isos using monoid
isos = [iso1, iso2, iso3]
composed = m_concat(%IsoCompose{}, isos)
```

### Identity Element

```elixir
# Identity iso does nothing
id = Iso.identity()

Iso.view(42, id)
# 42

Iso.review(42, id)
# 42

# Composing with identity is a no-op
Iso.compose(iso, Iso.identity()) == iso
Iso.compose(Iso.identity(), iso) == iso
```

## Anti-Patterns

### Don't Use Iso for Lossy Transformations

```elixir
# BAD: String -> Integer (parsing can fail)
bad_iso = Iso.make(
  &String.to_integer/1,  # Can crash!
  &Integer.to_string/1
)

# Use Prism instead
good_prism = Prism.make(
  fn s ->
    case Integer.parse(s) do
      {i, _} -> Maybe.just(i)
      :error -> Maybe.nothing()
    end
  end,
  &Integer.to_string/1
)
```

### Don't Use Iso for Partial Access

```elixir
# BAD: Accessing optional fields
bad_iso = Iso.make(
  fn map -> map.optional_field end,  # Might not exist!
  fn val -> %{optional_field: val} end
)

# Use Prism or Lens
good_prism = Prism.key(:optional_field)
```

### Don't Violate Round-Trip Laws

```elixir
# BAD: Not true inverses
bad_iso = Iso.make(
  fn s -> String.upcase(s) end,
  fn s -> String.downcase(s) end  # Loses information!
)

# "hello" -> "HELLO" -> "hello" ✓
# "Hello" -> "HELLO" -> "hello" ✗ (lost capitalization)
```

## Good Patterns

### Domain Type Conversions

```elixir
defmodule Money do
  defstruct [:cents]
end

# Cents <-> Dollars (always lossless with integer cents)
money_iso = Iso.make(
  fn %Money{cents: c} -> c / 100 end,
  fn dollars -> %Money{cents: round(dollars * 100)} end
)
```

### Encoding/Decoding

```elixir
# Base64 encoding (lossless)
base64_iso = Iso.make(
  &Base.encode64/1,
  &Base.decode64!/1
)

binary = "Hello, World!"
encoded = Iso.view(binary, base64_iso)
# "SGVsbG8sIFdvcmxkIQ=="

Iso.review(encoded, base64_iso)
# "Hello, World!"
```

### Newtype Wrappers

```elixir
defmodule UserId do
  defstruct [:id]
end

# Integer <-> UserId
user_id_iso = Iso.make(
  fn id -> %UserId{id: id} end,
  fn %UserId{id: id} -> id end
)
```

### Chaining Conversions

```elixir
# String -> Integer -> Cents -> Dollars
string_to_int = Iso.make(&String.to_integer/1, &Integer.to_string/1)
cents_to_dollars = Iso.make(fn c -> c / 100 end, fn d -> round(d * 100) end)

string_to_dollars = Iso.compose([string_to_int, cents_to_dollars])

Iso.view("1250", string_to_dollars)
# 12.5
```

## Integration with Other Optics

### Composing with Lenses

```elixir
# Iso + Lens = Lens
string_int_iso = Iso.make(&String.to_integer/1, &Integer.to_string/1)
iso_as_lens = Iso.as_lens(string_int_iso)

field_lens = Lens.key(:value)

# Compose: access field, then convert type
composed_lens = Lens.compose(field_lens, iso_as_lens)

data = %{value: "42"}
Lens.view(data, composed_lens)
# 42
```

### Composing with Prisms

```elixir
# Iso + Prism = Prism
optional_field = Prism.key(:amount)
string_int_iso = Iso.make(&String.to_integer/1, &Integer.to_string/1)
iso_as_prism = Iso.as_prism(string_int_iso)

# Compose: optional access, then convert
composed = Prism.compose(optional_field, iso_as_prism)

Prism.preview(%{amount: "100"}, composed)
# Just(100)

Prism.preview(%{}, composed)
# Nothing
```

## Performance Considerations

- Isos are pure function calls - minimal overhead
- Composition creates closures - avoid deep composition in hot loops
- Round-trip laws are not checked at runtime - ensure correctness at compile time
- `over` and `under` are efficient - single forward or backward transformation

## Testing Iso Laws

Property-based testing can verify iso laws:

```elixir
property "review-view law" do
  check all value <- term() do
    iso = my_iso()
    assert Iso.review(Iso.view(value, iso), iso) == value
  end
end

property "view-review law" do
  check all value <- term() do
    iso = my_iso()
    assert Iso.view(Iso.review(value, iso), iso) == value
  end
end
```

## Summary

`Funx.Optics.Iso` provides bidirectional, lossless transformations between equivalent representations. Isos are the most powerful optic, usable as both lenses and prisms, but require strict round-trip laws ensuring no information is lost in either direction.

Use isos for type conversions, format transformations, and encoding/decoding where both directions always succeed and preserve all data. For partial or lossy transformations, use Prism or Lens instead.
