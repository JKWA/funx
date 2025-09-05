# `Funx.Errors.ValidationError` Usage Rules

## Core Concepts

**Domain Validation**: User-facing validation errors with structured messages

- Wraps one or more validation failure messages
- Used with `Either.Left` to represent validation failures
- Composable and mergeable for comprehensive error collection

**Either Integration**: Primary use in Either-based validation chains

- `ValidationError` as Left value in `Either.Left` 
- Integrates with `Either.validate/2` for comprehensive validation
- Use `map_left` to wrap errors in ValidationError struct

**Appendable Composition**: Combine multiple validation errors

- `merge/2` - combines two ValidationError structs
- `Appendable` protocol - enables automatic error accumulation
- `empty/0` - provides identity for composition

## Quick Patterns

```elixir
alias Funx.Errors.ValidationError
import Funx.Monad, only: [map: 2, bind: 2]

# Single validator returning ValidationError
validate_positive = fn x ->
  if x > 0 do
    Either.right(x)
  else
    Either.left(ValidationError.new("Value must be positive: #{x}"))
  end
end

# PREFERRED: Use Either.validate/2 for comprehensive validation
validators = [
  fn x -> Either.lift_predicate(x, &(&1 > 0), "Must be positive")
           |> Either.map_left(&ValidationError.new/1) end,
  fn x -> Either.lift_predicate(x, &(rem(&1, 2) == 0), "Must be even") 
           |> Either.map_left(&ValidationError.new/1) end
]

Either.validate(-3, validators)
# Left(ValidationError{errors: ["Must be positive", "Must be even"]})

# Form validation with comprehensive errors
Either.validate(form_data, [
  &validate_name_field/1,
  &validate_email_field/1, 
  &validate_age_field/1
]) |> Either.map_left(&format_validation_response/1)
```

## Key Rules

- **Always wrap in Either.Left** for validation failures - never use bare ValidationError
- **Use list format for errors** - `["error1", "error2"]` not single strings
- **Prefer Either.validate/2** over manual error accumulation
- **Use map_left to wrap** regular error messages in ValidationError struct
- **Implement Exception** behavior when validation must halt execution
- **Merge compatible** - use `merge/2` to combine multiple ValidationError instances

## When to Use

- Form validation with multiple field errors
- Domain validation that collects all problems
- API validation responses that need comprehensive error lists
- Business rule validation with structured error reporting
- Validation chains where partial success isn't meaningful

## Anti-Patterns

```elixir
# Don't use ValidationError directly without Either
def validate_user(user) do
  ValidationError.new("Invalid user")  # No context!
end

# Don't mix ValidationError with simple strings in Left
Either.left("simple error")  # Then later...
Either.left(ValidationError.new("structured error"))  # Inconsistent!

# Don't forget to accumulate errors
def validate_fields(data) do
  case validate_name(data.name) do
    {:error, name_error} -> Either.left(ValidationError.new(name_error))
    {:ok, _} ->
      case validate_email(data.email) do  # Lost name validation!
        {:error, email_error} -> Either.left(ValidationError.new(email_error))
        {:ok, _} -> Either.right(data)
      end
  end
end

# Don't create ValidationError with single string when you need lists
ValidationError.new("single error")  # Use list format for consistency
```

## Testing

```elixir
test "validation error accumulation" do
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
    _ -> flunk("Expected validation errors")
  end
end

test "ValidationError composition" do
  ve1 = ValidationError.new(["error 1"])
  ve2 = ValidationError.new(["error 2"]) 
  
  merged = ValidationError.merge(ve1, ve2)
  assert merged.errors == ["error 1", "error 2"]
end

test "Exception behavior" do
  assert_raise ValidationError, "must be positive", fn ->
    raise ValidationError, errors: ["must be positive"]
  end
end
```

## Core Functions

### Construction Functions

```elixir
# Create from list of error messages
ValidationError.new(["must be positive", "must be even"])

# Create from single error message  
ValidationError.new("must be positive")
# Result: %ValidationError{errors: ["must be positive"]}

# Empty validation error (identity for composition)
ValidationError.empty()
# Result: %ValidationError{errors: []}

# Convert from tagged error tuple
ValidationError.from_tagged({:error, ["field errors"]})
```

### Composition Functions

```elixir
# Merge two ValidationError structs
ve1 = ValidationError.new(["error 1"])
ve2 = ValidationError.new(["error 2"])
ValidationError.merge(ve1, ve2)
# Result: %ValidationError{errors: ["error 1", "error 2"]}

# Appendable protocol (automatic with Either.validate/2)
import Funx.Appendable
append(ve1, ve2)  # Same as merge/2
```

### Exception Functions

```elixir
# Raise as exception with error list
raise ValidationError, errors: ["critical validation failure"]

# Raise as exception with single message
raise ValidationError, "critical validation failure"  

# Get exception message
Exception.message(%ValidationError{errors: ["a", "b"]})
# Result: "a, b"
```

## Integration with Either

### Validation Chains

```elixir
# Sequential validation (fails on first error)
Either.right(user_input)
|> bind(&parse_user_data/1)
|> bind(&validate_business_rules/1)  # Returns Either with ValidationError
|> bind(&save_to_database/1)

# Comprehensive validation (collects all errors)  
Either.validate(user_data, [
  &validate_name/1,     # Each returns Either Left(ValidationError) or Right
  &validate_email/1,
  &validate_age/1
])
```

### Converting Simple Errors to ValidationError

```elixir
# Wrap simple error messages
simple_validator = fn data ->
  if valid?(data) do
    Either.right(data)
  else
    Either.left("Invalid data")
  end
end

# Convert to ValidationError format
enhanced_validator = fn data ->
  simple_validator.(data)
  |> Either.map_left(&ValidationError.new/1)
end

# Or use lift_predicate with map_left
validate_positive = fn x ->
  Either.lift_predicate(x, &(&1 > 0), "Must be positive")
  |> Either.map_left(&ValidationError.new/1)
end
```

### Form Validation Pattern

```elixir
def validate_registration_form(form_data) do
  validators = [
    create_name_validator(form_data),
    create_email_validator(form_data), 
    create_password_validator(form_data)
  ]
  
  Either.validate(form_data, validators)
  |> case do
    %Right{right: validated_data} -> 
      {:ok, validated_data}
    %Left{left: %ValidationError{errors: errors}} ->
      {:error, %{validation_errors: errors}}
  end
end

defp create_name_validator(form_data) do
  fn _data ->
    if String.length(form_data.name) > 0 do
      Either.right(form_data.name)
    else
      Either.left(ValidationError.new(["Name is required"]))
    end
  end
end
```

## Protocol Implementations

### String.Chars

```elixir
to_string(ValidationError.new(["error 1", "error 2"]))
# Result: "ValidationError(error 1, error 2)"

to_string(ValidationError.empty())
# Result: "ValidationError()"
```

### Funx.Eq and Funx.Ord

```elixir
# Comparison based on errors list
ve1 = ValidationError.new(["a"])
ve2 = ValidationError.new(["b"])

Eq.eq?(ve1, ve1)        # true  
Eq.eq?(ve1, ve2)        # false
Ord.lt?(ve1, ve2)       # true ("a" < "b")
```

### Funx.Appendable

```elixir
# Automatic composition in Either.validate/2
import Funx.Appendable

ve1 = ValidationError.new(["error 1"])
ve2 = ValidationError.new(["error 2"])

append(ve1, ve2)
# Result: %ValidationError{errors: ["error 1", "error 2"]}
```

## Advanced Patterns

### Curried Validation Functions

```elixir
# Create reusable validators with currying
validate_height = curry_r(&ensure_height/2)
validate_age = curry_r(&ensure_age/2)

# Apply to specific context
patron
|> Either.validate([
  validate_height.(ride),
  validate_age.(ride) 
])
```

### Fallback Validation with or_else

```elixir
# Try primary validation, fallback to secondary  
def ensure_vip_or_fast_pass(patron, ride) do
  patron
  |> Either.lift_predicate(&Patron.vip?/1, "#{Patron.get_name(patron)} is not a VIP")
  |> Either.map_left(&ValidationError.new/1)
  |> Either.or_else(fn -> ensure_fast_pass(patron, ride) end)
end
```

### Sequential vs Comprehensive Validation

```elixir
# Sequential: stop on first failure (bind)
def ensure_eligibility(patron, ride) do
  validate_height = curry_r(&ensure_height/2)
  
  patron
  |> ensure_age(ride)
  |> bind(validate_height.(ride))
end

# Comprehensive: collect all failures (validate)
def validate_eligibility(patron, ride) do
  validate_height = curry_r(&ensure_height/2)
  validate_age = curry_r(&ensure_age/2)
  
  patron
  |> Either.validate([
    validate_height.(ride),
    validate_age.(ride)
  ])
end
```

### Error Message Transformation

```elixir
# Transform detailed errors to user-friendly messages
validate_eligibility = curry_r(fn patron, ride ->
  validate_eligibility(patron, ride)
  |> Either.map_left(fn _ -> 
    "#{Patron.get_name(patron)} is not eligible for this ride"
  end)
end)

# Select first error from comprehensive validation
Either.validate(patron, validators)
|> Either.map_left(fn [first | _] -> first end)
```

### List Validation Patterns

```elixir
# Fail-fast list validation (traverse)
def ensure_group_eligibility(patrons, ride) do
  eligible_for_ride = curry_r(&ensure_eligibility/2)
  
  Either.traverse(patrons, eligible_for_ride.(ride))
end

# Comprehensive list validation (traverse_a)
def validate_group_eligibility(patrons, ride) do  
  validate_eligibility = curry_r(&validate_eligibility/2)
  
  Either.traverse_a(patrons, validate_eligibility.(ride))
end
```

## Common Patterns

### API Validation Response

```elixir
def validate_api_request(request) do
  validators = [
    &validate_authentication/1,
    &validate_authorization/1,
    &validate_request_format/1,
    &validate_business_rules/1
  ]
  
  case Either.validate(request, validators) do
    %Right{right: valid_request} ->
      {:ok, valid_request}
    %Left{left: %ValidationError{errors: errors}} ->
      {:error, %{
        status: :validation_failed,
        errors: errors,
        timestamp: DateTime.utc_now()
      }}
  end
end
```

### Multi-Step Validation

```elixir
def validate_user_registration(data) do
  # Step 1: Format validation
  format_result = Either.validate(data, [
    &validate_email_format/1,
    &validate_password_format/1
  ])
  
  # Step 2: Business rules validation (only if format is valid)
  case format_result do
    %Right{right: _} ->
      Either.validate(data, [
        &validate_email_unique/1,
        &validate_password_strength/1
      ])
    error -> error
  end
end
```

### Error Recovery

```elixir
def process_with_validation(data) do
  case validate_strict_rules(data) do
    %Right{right: valid_data} -> 
      {:ok, valid_data}
    %Left{left: %ValidationError{errors: errors}} ->
      # Try lenient validation on failure
      if recoverable_errors?(errors) do
        validate_lenient_rules(data)
      else
        {:error, errors}
      end
  end
end
```

## Performance Considerations

- ValidationError creation is lightweight (just list wrapping)
- Error message concatenation happens lazily in `Exception.message/1` 
- `merge/2` uses simple list concatenation - efficient for typical error counts
- Appendable protocol enables efficient accumulation in Either.validate/2
- String formatting only happens when converting to string representation

## Best Practices

- Use ValidationError for user-facing validation only
- Always wrap in Either.Left, never return bare ValidationError
- Prefer list format for errors even for single messages  
- Use Either.validate/2 for comprehensive validation
- Structure error messages consistently across your application
- Include context in error messages (field names, values, constraints)
- Test both successful validation and error accumulation paths
- Consider internationalization when designing error messages

## Error Message Guidelines

```elixir
# Good: Specific, actionable error messages
"Email field is required"
"Password must be at least 8 characters"
"Age must be between 13 and 120"

# Avoid: Vague or technical error messages  
"Invalid input"
"Validation failed"  
"Error in field processing"

# Good: Include context and constraints
ValidationError.new(["Username '#{username}' is already taken"])
ValidationError.new(["Price #{price} must be greater than $0.00"])

# Good: Use Either.lift_predicate for simple validation
def validate_required_field(value, field_name) do
  Either.lift_predicate(value, &present?/1, "#{field_name} is required")
  |> Either.map_left(&ValidationError.new/1)
end
```
