# Funx Usage Rules (Index)

Usage rules describe how to use Funx protocols and utilities in practice.
They complement the module docs (which describe *what* the APIs do).

Each protocol or major module has its own usage rules in `./usage-rules`.
This index links them together.

## Approach

These usage rules emphasize **practical application over academic theory**, focusing on real-world patterns, business problems, and incremental adoption. The goal is to make functional programming approachable and immediately useful, not an abstract mathematical exercise.

These rules provide guidance on how to effectively apply functional patterns in Elixir production systems.

## Available Rules

- Funx.Appendable Usage Rules - **funx:appendable usage**
  Flexible aggregation for accumulating results - structured vs flat collection strategies.

- Funx.Eq Usage Rules - **funx:eq usage**
  Domain-specific equality and identity for comparison, deduplication, and filtering.

- Funx.Errors.ValidationError Usage Rules - **funx:errors_validation_error usage**
  Domain validation with structured error collection, composition, and Either integration.

- Funx.Foldable Usage Rules - **funx:foldable usage**
  Conditional structure collapse with different functions for present vs absent cases—defaults and aggregation.

- Funx.List Usage Rules - **funx:list usage**
  Equality- and order-aware set operations, deduplication, and sorting.

- Funx.Monad Usage Rules - **funx:monad usage**
  Declarative control flow with `map`, `bind`, and `ap`—composing context-aware steps.

- Funx.Monad.Either Usage Rules - **funx:monad_either usage**
  Branching computation with error context—fail fast or accumulate validation errors.

- Funx.Monad.Effect Usage Rules - **funx:monad_effect usage**
  Deferred observable async computation—Reader + Either + async execution with full telemetry.

- Funx.Monad.Identity Usage Rules - **funx:monad_identity usage**
  Structure without effects—used as a baseline for composing monads.

- Funx.Monad.Maybe Usage Rules - **funx:monad_maybe usage**
  Optional computation: preserve structure, short-circuit on absence, avoid `nil`.

- Funx.Monad.Reader Usage Rules - **funx:monad_reader usage**
  Deferred computation with read-only environment access—dependency injection and configuration.

- Funx.Monad.Writer Usage Rules - **funx:monad_writer usage**
  Computation with accumulated log—monoid-based logging and audit trails.

- Funx.Monoid Usage Rules - **funx:monoid usage**
  Identity and associative combination, enabling folds, logs, and accumulation.

- Funx.Ord Usage Rules - **funx:ord usage**
  Context-aware ordering for sorting, ranking, and prioritization.

- Funx.Predicate Usage Rules - **funx:predicate usage**
  Logical composition using `&&`/`||`, reusable combinators, and lifted conditions.

- Funx.Utils Usage Rules - **funx:utils usage**
  Currying, flipping, and function transformation for point-free, pipeline-friendly composition.

## Conventions

- Scope: focus on *usage guidance* and best practices, not API reference.
- LLM-friendly: small sections, explicit examples, stable links.

## Project Layout (rules only)

```text
usage-rules.md                # ← index (this file)
usage-rules/
  appendable.md               # ← Funx.Appendable rules
  eq.md                       # ← Funx.Eq rules
  errors_validation_error.md  # ← Funx.Errors.ValidationError rules
  foldable.md                 # ← Funx.Foldable rules
  list.md                     # ← Funx.List rules
  monad.md                    # ← Funx.Monad rules
  monad_either.md             # ← Funx.Monad.Either rules
  monad_effect.md             # ← Funx.Monad.Effect rules
  monad_identity.md           # ← Funx.Monad.Identity rules
  monad_maybe.md              # ← Funx.Monad.Maybe rules
  monad_reader.md             # ← Funx.Monad.Reader rules
  monad_writer.md             # ← Funx.Monad.Writer rules
  monoid.md                   # ← Funx.Monoid rules
  ord.md                      # ← Funx.Ord rules
  predicate.md                # ← Funx.Predicate rules
  utils.md                    # ← Funx.Utils rules
```

## Domain Model + Repository Pattern Usage Rules

### Core Concepts

**Functional Domain-Driven Design**: Domain model with validation, healing, and repository patterns using Funx functional programming constructs.

**Never-Fail Constructors**: Use transformation over validation to create always-valid data structures.

**Separate Validation**: Domain rules validation is separate from data integrity (healing).

**Repository Abstraction**: Clean separation between domain logic and storage concerns.

### Quick Patterns

```elixir
# Domain Model Structure
defmodule MyEntity do
  import Funx.Predicate
  alias Funx.Monad.Either
  alias Funx.Errors.ValidationError

  @type t :: %__MODULE__{
    id: pos_integer(),
    required_field: String.t(),
    optional_field: String.t() | nil
  }

  @enforce_keys [:id, :required_field, :optional_field]
  defstruct [:id, :required_field, optional_field: nil]

  # Domain Constants
  @default_value "Default"

  # Predicates (boolean checks)
  def invalid_field?(%__MODULE__{required_field: field}), do: field == @default_value

  # Validation Functions (Either-wrapped)
  def ensure_field(%__MODULE__{} = entity) do
    entity
    |> Either.lift_predicate(
      p_not(&invalid_field?/1),
      fn e -> "Entity '#{e.required_field}' is invalid" end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  # Complete Validation
  def validate(%__MODULE__{} = entity) do
    entity |> Either.validate([&ensure_field/1])
  end

  # Never-Fail Constructor
  def make(required_field, opts \\ []) do
    %__MODULE__{
      id: :erlang.unique_integer([:positive]),
      required_field: required_field,
      optional_field: Keyword.get(opts, :optional_field)
    }
    |> heal_entity()
  end

  # Safe Change (with healing)
  def change(%__MODULE__{} = entity, attrs) when is_map(attrs) do
    attrs = Map.delete(attrs, :id)
    entity |> struct(attrs) |> heal_entity()
  end

  # Unsafe Change (for testing)
  def unsafe_change(%__MODULE__{} = entity, attrs) when is_map(attrs) do
    attrs = Map.delete(attrs, :id)
    entity |> struct(attrs)
  end

  # Self-Healing Function
  def heal_entity(%__MODULE__{} = entity) do
    %{entity | required_field: heal_field(entity.required_field)}
  end

  defp heal_field(field) when is_binary(field) and byte_size(field) > 0, do: field
  defp heal_field(_), do: @default_value

  # Field Accessors (encapsulation)
  def id(%__MODULE__{id: id}), do: id
  def required_field(%__MODULE__{required_field: field}), do: field
end

# Protocol Implementations
defimpl Funx.Eq, for: MyEntity do
  alias Funx.Eq
  alias MyEntity
  def eq?(%MyEntity{id: v1}, %MyEntity{id: v2}), do: Eq.eq?(v1, v2)
  def not_eq?(%MyEntity{id: v1}, %MyEntity{id: v2}), do: not eq?(v1, v2)
end

defimpl Funx.Ord, for: MyEntity do
  alias Funx.Ord
  alias MyEntity
  def lt?(%MyEntity{required_field: v1}, %MyEntity{required_field: v2}), do: Ord.lt?(v1, v2)
  def le?(%MyEntity{required_field: v1}, %MyEntity{required_field: v2}), do: Ord.le?(v1, v2)
  def gt?(%MyEntity{required_field: v1}, %MyEntity{required_field: v2}), do: Ord.gt?(v1, v2)
  def ge?(%MyEntity{required_field: v1}, %MyEntity{required_field: v2}), do: Ord.ge?(v1, v2)
end

# Repository Pattern
defmodule MyEntity.Repo do
  import Funx.Monad
  import Funx.Utils, only: [curry: 1]

  alias Funx.Monad.Either
  alias Funx.List
  alias MyEntity
  alias Store

  @table_name :my_entity

  def create_table do
    Store.create_table(@table_name)
  end

  def save(%MyEntity{} = entity) do
    insert_entity = curry(&Store.insert_item/2)

    entity
    |> MyEntity.validate()
    |> bind(insert_entity.(@table_name))
  end

  def get(id) when is_integer(id) do
    Store.get_item(@table_name, id)
    |> map(fn data -> struct(MyEntity, data) end)
    |> Either.map_left(fn _ -> :not_found end)
  end

  def list() do
    Store.get_all_items(@table_name)
    |> map(fn items ->
      items
      |> Enum.map(fn item -> struct(MyEntity, item) end)
      |> List.sort()
    end)
    |> Either.get_or_else([])
  end

  def delete(%MyEntity{id: id}) do
    Store.delete_item(@table_name, id)
    |> Either.get_or_else(:ok)
  end
end
```

### Key Rules

#### Domain Model Rules

- **Always use @enforce_keys** for required struct fields
- **Define @type for your struct** with proper type annotations
- **Use module constants** for domain constraints (@min_value, @default_name, etc.)
- **Predicate functions** end with `?` and return boolean
- **Validation functions** start with `ensure_` and return Either
- **Constructor never fails** - use `make/2` with healing
- **Provide safe/unsafe change** - `change/2` heals, `unsafe_change/2` doesn't
- **Encapsulate with accessors** - don't access struct fields directly
- **Use Either.validate/2** to collect all validation errors

#### Validation Pattern

```elixir
# 1. Predicate (boolean check)
def invalid_thing?(%__MODULE__{field: value}), do: some_check(value)

# 2. Validation function (Either-wrapped)
def ensure_thing(%__MODULE__{} = entity) do
  entity
  |> Either.lift_predicate(
    p_not(&invalid_thing?/1),
    fn e -> "Descriptive error message with #{e.field}" end
  )
  |> Either.map_left(&ValidationError.new/1)
end

# 3. Add to comprehensive validation
def validate(%__MODULE__{} = entity) do
  entity |> Either.validate([&ensure_thing/1, &ensure_other/1])
end
```

#### Protocol Implementation Pattern

```elixir
# Equality by ID (identity)
defimpl Funx.Eq, for: MyType do
  alias Funx.Eq
  alias MyType
  def eq?(%MyType{id: v1}, %MyType{id: v2}), do: Eq.eq?(v1, v2)
  def not_eq?(%MyType{id: v1}, %MyType{id: v2}), do: not eq?(v1, v2)
end

# Ordering by display field (sorting)
defimpl Funx.Ord, for: MyType do
  alias Funx.Ord
  alias MyType
  def lt?(%MyType{name: v1}, %MyType{name: v2}), do: Ord.lt?(v1, v2)
  def le?(%MyType{name: v1}, %MyType{name: v2}), do: Ord.le?(v1, v2)
  def gt?(%MyType{name: v1}, %MyType{name: v2}), do: Ord.gt?(v1, v2)
  def ge?(%MyType{name: v1}, %MyType{name: v2}), do: Ord.ge?(v1, v2)
end
```

#### Repository Rules

- **Import Funx.Monad** for bind, map operations
- **Import curry/1** from Funx.Utils for partial application
- **Use @table_name** constant for ETS table
- **Always validate before save** - `validate() |> bind(insert_...)`
- **Use curry for partial application** - `curry(&Store.insert_item/2)`
- **Map data back to structs** on retrieval
- **Use Either.get_or_else** for sensible defaults
- **Handle not_found** with Either.map_left
- **Auto-sort lists** using protocol-defined ordering

#### Self-Healing Pattern

```elixir
def heal_entity(%__MODULE__{} = entity) do
  %{entity |
    field1: heal_field1(entity.field1),
    field2: heal_field2(entity.field2)
  }
end

# Individual field healing functions
defp heal_field1(value) when is_binary(value) and byte_size(value) > 0, do: value
defp heal_field1(_), do: @default_value

defp heal_field2(value) when is_integer(value) and value > 0, do: value
defp heal_field2(_), do: 1
```

### When to Use

- **Domain entities** with complex business rules
- **Data that needs validation** but should never fail to construct
- **Entities requiring persistence** with repository pattern
- **Types needing custom comparison** semantics
- **Systems preferring transformation** over validation errors

### Anti-Patterns

```elixir
# Don't access struct fields directly
hero.name  # Use Hero.name(hero) instead

# Don't use plain strings in Either.left
Either.left("error")  # Use ValidationError

# Don't mix validation concerns
def make(name) do
  if valid_name?(name) do
    %Hero{name: name}  # This can fail!
  else
    {:error, "invalid"}
  end
end

# Don't forget ID protection in change functions
def change(entity, attrs) do
  struct(entity, attrs)  # Allows ID modification!
end

# Don't skip validation in repository save
def save(entity) do
  Store.insert_item(@table, entity)  # No validation!
end
```

### Testing Patterns

```elixir
# Use unsafe_change to create invalid entities for testing
invalid_entity = MyEntity.unsafe_change(entity, %{field: "invalid"})

# Test that validation catches issues
case MyEntity.validate(invalid_entity) do
  %Either.Left{left: %ValidationError{errors: errors}} ->
    assert "expected error" in errors
  _ -> flunk("Expected validation failure")
end

# Test self-healing
healed = MyEntity.heal_entity(invalid_entity)
assert MyEntity.field(healed) == "default"
```

### Performance Considerations

- Self-healing is lightweight transformation
- Either.validate/2 collects all errors in single pass
- Protocol dispatch for Eq/Ord is efficient
- ETS operations are wrapped safely with Either.from_try
- Currying creates closures - use judiciously

### Best Practices

- Use descriptive error messages with entity context
- Keep domain constants at module level
- Implement both Eq and Ord protocols when needed
- Test both happy path and error accumulation
- Use repository for all persistence operations
- Never expose struct fields directly
- Prefer transformation over validation failure
- Use curry for reusable partially-applied functions
