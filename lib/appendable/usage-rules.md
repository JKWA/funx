# `Funx.Appendable` Usage Rules

## Core Concepts

**Protocol + Any Fallback Pattern**: Use both together for maximum flexibility

- **Protocol implementation** = custom aggregation logic for your domain types
- **Any fallback** = flat list aggregation when no custom implementation exists
- **Key insight**: Protocol provides structured accumulation, fallback provides universal compatibility

**Coerce + Append Pattern**: Two-step aggregation process

- `coerce/1` - normalizes input value into aggregatable form
- `append/2` - combines two values of the same type
- **Key pattern**: coerce first, then append - enables type-safe accumulation

**Structured vs Flat Aggregation**: Choose accumulation strategy

- **Flat aggregation** - uses Any fallback, collects values in plain list
- **Structured aggregation** - uses custom protocol, maintains domain semantics

## Decision: When to Use Each Strategy

### Use Protocol When:
- You need domain-specific aggregation logic (ValidationError, Metrics, FormErrors)
- Error context matters for debugging or user feedback
- Combining values requires business logic (timestamps, severity levels, nested structures)
- Type safety and structured data are important for downstream processing

### Use Fallback When:
- Simple collection is sufficient for your use case
- You're working with heterogeneous data that doesn't need domain structure
- Performance is critical and flat lists meet your needs
- You're prototyping or in early development phases

## Quick Patterns

```elixir
# STEP 1: Use Any fallback for simple aggregation
validate_positive = fn x ->
  Either.lift_predicate(x, &(&1 > 0), "Must be positive: #{x}")
end

Either.validate(-3, [validate_positive])
# Left(["Must be positive: -3"])  # Flat list via Any fallback

# STEP 2: Implement protocol for structured aggregation
defimpl Funx.Appendable, for: ValidationError do
  def coerce(%ValidationError{errors: e}), do: ValidationError.new(e)
  def append(%ValidationError{} = acc, %ValidationError{} = other) do
    ValidationError.merge(acc, other)
  end
end

# STEP 3: Use structured aggregation with custom protocol
validate_with_structure = fn x ->
  Either.lift_predicate(x, &(&1 > 0), "Must be positive: #{x}")
  |> Either.map_left(&ValidationError.new/1)
end

Either.validate(-3, [validate_with_structure])
# Left(ValidationError{errors: ["Must be positive: -3"]})  # Structured

# STEP 4: Custom domain aggregation
defimpl Funx.Appendable, for: MyErrorReport do
  def coerce(%MyErrorReport{} = report), do: report
  def append(%MyErrorReport{errors: e1}, %MyErrorReport{errors: e2}) do
    %MyErrorReport{
      errors: e1 ++ e2,
      timestamp: DateTime.utc_now(),
      severity: max_severity(e1, e2)
    }
  end
end
```

## Key Rules

- **IMPLEMENT PROTOCOL** when you need structured, domain-specific aggregation
- **USE ANY FALLBACK** when flat list accumulation is sufficient
- **MUST implement both** `coerce/1` and `append/2` (no optional defaults)
- **ENSURE ASSOCIATIVITY** - `append(append(a, b), c) = append(a, append(b, c))`
- **Pattern**: Custom protocol for structure, fallback for simplicity
- **Integration**: Powers `validate/2`, `traverse_a/2`, and other accumulating operations

## When to Use

- **Protocol implementation**: When you need structured aggregation with domain semantics
- **Any fallback**: When simple list collection is sufficient for your use case
- **Validation chains**: Error accumulation in `Either.validate/2`
- **Parallel operations**: Result collection in `traverse_a/2`
- **Custom domains**: Metrics, logs, reports that need special combination logic

## Anti-Patterns

```elixir
# ❌ Don't forget associativity requirement
defimpl Funx.Appendable, for: BadExample do
  def append(a, b), do: %BadExample{value: a.value - b.value}  # Not associative!
end

# ❌ Don't mix flat and structured in same pipeline
Either.validate(data, [
  fn x -> Either.left("simple error") end,              # String
  fn x -> Either.left(ValidationError.new("struct")) end # ValidationError - inconsistent!
])

# ❌ Don't implement protocol unnecessarily
defimpl Funx.Appendable, for: SimpleList do
  def coerce(list), do: list
  def append(a, b), do: a ++ b  # Same as Any fallback - unnecessary!
end

# ❌ Don't violate coerce expectations
defimpl Funx.Appendable, for: WrongExample do
  def coerce(value), do: transform_completely(value)  # Should normalize, not transform!
  def append(a, b), do: combine(a, b)
end
```

## Testing

```elixir
test "Appendable laws hold" do
  e1 = ValidationError.new(["error 1"])
  e2 = ValidationError.new(["error 2"])
  e3 = ValidationError.new(["error 3"])
  
  # Associativity: (a + b) + c = a + (b + c)
  left_assoc = Appendable.append(Appendable.append(e1, e2), e3)
  right_assoc = Appendable.append(e1, Appendable.append(e2, e3))
  assert left_assoc.errors == right_assoc.errors
end

test "coerce normalizes values" do
  # Coerce should normalize, not transform
  original = ValidationError.new(["test"])
  coerced = Appendable.coerce(original)
  assert coerced == original  # Should be normalized form
end

test "Any fallback works for unknown types" do
  # Any implementation provides universal compatibility
  result = Appendable.append("hello", "world")
  assert result == ["hello", "world"]
  
  result = Appendable.append(["a", "b"], "c")
  assert result == ["a", "b", "c"]
end

test "integration with Either.validate" do
  validators = [
    fn x -> if x > 0, do: Either.right(x), 
            else: Either.left(ValidationError.new(["must be positive"])) end,
    fn x -> if rem(x, 2) == 0, do: Either.right(x), 
            else: Either.left(ValidationError.new(["must be even"])) end
  ]
  
  case Either.validate(-3, validators) do
    %Left{left: %ValidationError{errors: errors}} ->
      assert "must be positive" in errors
      assert "must be even" in errors
      assert length(errors) == 2
    _ -> flunk("Expected accumulated validation errors")
  end
end
```

## Core Functions

### Protocol Functions

```elixir
# Normalize value for aggregation
Appendable.coerce(ValidationError.new(["error"]))
# Result: %ValidationError{errors: ["error"]}

# Combine two values
ve1 = ValidationError.new(["error 1"])
ve2 = ValidationError.new(["error 2"])
Appendable.append(ve1, ve2)
# Result: %ValidationError{errors: ["error 1", "error 2"]}
```

### Any Fallback Functions

```elixir
# Universal list coercion
Appendable.coerce("single value")  # Result: ["single value"]
Appendable.coerce(["already", "list"])  # Result: ["already", "list"]

# Universal list combination
Appendable.append(["a", "b"], ["c", "d"])  # Result: ["a", "b", "c", "d"]
Appendable.append("single", ["list"])      # Result: ["single", "list"]
```

## How the Any Fallback Works

**Automatic List Coercion**: Values are normalized into lists for universal compatibility

- `coerce("single value")` → `["single value"]` (wraps non-lists)
- `coerce(["already", "list"])` → `["already", "list"]` (preserves lists)
- **Key insight**: Every value becomes list-compatible for aggregation

**Flat List Combination**: Uses `++` operator for simple concatenation

- `append(["a", "b"], ["c", "d"])` → `["a", "b", "c", "d"]`
- `append("single", ["list"])` → `["single", "list"]` (coerces then appends)
- **Performance note**: O(n) for each append operation due to list concatenation

**Protocol Dispatch Skip**: When no custom implementation exists, Any fallback activates

- No struct-specific logic needed
- Universal compatibility across all types
- Simple, predictable behavior for mixed-type scenarios

## Integration with Monadic Operations

### Either.validate Integration

**Note on map_left**: While Appendable itself doesn't provide `map`, it frequently appears within monadic transformations like `map_left` for wrapping structured errors.

```elixir
# Flat aggregation (Any fallback)
Either.validate(data, [
  fn x -> Either.left("error 1") end,
  fn x -> Either.left("error 2") end
])
# Result: Left(["error 1", "error 2"])

# Structured aggregation (custom protocol with map_left)
validate_with_structure = fn x ->
  Either.lift_predicate(x, &valid?/1, "validation failed")
  |> Either.map_left(&ValidationError.new/1)  # map_left wraps for Appendable
end

Either.validate(data, [validate_with_structure])
# Result: Left(ValidationError{errors: ["validation failed"]})
```

### traverse_a Integration

```elixir
# Accumulate results using Appendable
data = [invalid1, invalid2, valid3]
kleisli_validator = fn item ->
  if valid?(item) do
    Either.right(process(item))
  else
    Either.left(ValidationError.new(["Invalid: #{item}"]))
  end
end

Either.traverse_a(data, kleisli_validator)
# Result: Left(ValidationError{errors: ["Invalid: invalid1", "Invalid: invalid2"]})
```

### Custom Domain Integration

```elixir
# Custom metrics aggregation
defimpl Funx.Appendable, for: Metrics do
  def coerce(%Metrics{} = m), do: m
  def append(%Metrics{count: c1, sum: s1}, %Metrics{count: c2, sum: s2}) do
    %Metrics{count: c1 + c2, sum: s1 + s2}
  end
end

# Use with parallel operations
Either.traverse_a(data, &collect_metrics/1)
# Result: Right(Metrics{count: total_count, sum: total_sum})
```

## Advanced Patterns

### Conditional Aggregation

```elixir
# Choose aggregation strategy based on context
def validate_with_strategy(data, strategy) do
  validators = case strategy do
    :strict -> strict_validators() |> Enum.map(&wrap_in_validation_error/1)
    :lenient -> lenient_validators()  # Use Any fallback
  end
  
  Either.validate(data, validators)
end
```

### Monoid-like Aggregation

```elixir
# Empty/identity-like behavior
defimpl Funx.Appendable, for: OptionalResult do
  def coerce(%OptionalResult{} = r), do: r
  def append(%OptionalResult{present: false}, other), do: other  # Identity-like
  def append(first, %OptionalResult{present: false}), do: first  # Identity-like
  def append(first, second), do: combine_results(first, second)
end
```

### Hierarchical Aggregation

```elixir
# Nested error structures
defimpl Funx.Appendable, for: FormErrors do
  def coerce(%FormErrors{} = fe), do: fe
  def append(%FormErrors{field_errors: fe1}, %FormErrors{field_errors: fe2}) do
    %FormErrors{
      field_errors: Map.merge(fe1, fe2, fn _key, v1, v2 -> 
        Appendable.append(v1, v2)  # Recursive aggregation
      end)
    }
  end
end
```

## Performance Considerations

- Appendable operations should be efficient for repeated aggregation
- `coerce/1` is called on every value - keep it lightweight
- `append/2` is called repeatedly during accumulation - optimize for performance
- Consider lazy evaluation for expensive aggregation operations
- Any fallback uses list concatenation - O(n) for each append operation

## Best Practices

- Implement Appendable for types that need structured accumulation
- Keep coerce/1 as a normalization step, not a transformation
- Ensure append/2 is associative for predictable behavior
- Use Any fallback when simple list collection is sufficient
- Test associativity law in your implementations
- Consider performance implications of repeated aggregation
- Document domain-specific aggregation semantics clearly

## Design Patterns

### Error Accumulation Pattern

Use Appendable to collect validation errors without coupling to specific error types:

```elixir
def validate_user(user_data) do
  validators = [
    &validate_email/1,
    &validate_password/1,
    &validate_age/1
  ]
  
  Either.validate(user_data, validators)  # Uses Appendable automatically
end
```

### Metrics Collection Pattern

Aggregate domain metrics using custom Appendable implementations:

```elixir
def collect_processing_metrics(items) do
  Either.traverse_a(items, &process_with_metrics/1)
  # Automatically aggregates metrics using custom Appendable
end
```

### Flexible Aggregation Pattern

Choose aggregation strategy at runtime without changing core logic:

```elixir
def process_with_aggregation(data, error_type) do
  validator = case error_type do
    :structured -> &wrap_in_custom_error/1
    :simple -> &return_simple_string/1
  end
  
  Either.validate(data, [validator])  # Appendable handles both cases
end
```

## Summary

`Funx.Appendable` provides **flexible, type-safe aggregation** for accumulating results across monadic operations:

- **Custom protocol** - implement for structured, domain-specific aggregation
- **Any fallback** - universal flat list aggregation for simple cases  
- **Two-step process** - coerce for normalization, append for combination
- **Associative requirement** - ensures predictable aggregation behavior
- **Monadic integration** - powers `validate/2`, `traverse_a/2`, and other accumulating operations
- **Performance aware** - optimize coerce/append for repeated aggregation scenarios

**Canon**: Use custom Appendable for structured accumulation, rely on Any fallback for simple collection, ensure associativity in implementations.