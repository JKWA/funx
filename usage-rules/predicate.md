# `Funx.Predicate` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Predicate**: A function that tests conditions and returns boolean values

- **Type signature**: `a -> boolean` (takes a value, returns true/false)
- **Purpose**: Enable composable, reusable validation and filtering logic
- **Mathematical foundation**: Based on Boolean algebra with logical operations
- **Composition**: Predicates can be combined using AND, OR, NOT operations

**Monoid Backing**: Predicates are backed by monoid operations for composition

- **All monoid (AND-based)**: Short-circuits on first false, requires all conditions to be true
- **Any monoid (OR-based)**: Short-circuits on first true, succeeds if any condition is true
- **Identity elements**: `always_true` for All, `always_false` for Any
- **Associativity**: Order of composition doesn't affect result

**Logical Laws**: Predicates follow Boolean algebra laws

- **Identity**: `p AND true = p`, `p OR false = p`
- **Commutativity**: `p AND q = q AND p`, `p OR q = q OR p`
- **Associativity**: `(p AND q) AND r = p AND (q AND r)`
- **De Morgan's Laws**: `NOT(p AND q) = NOT p OR NOT q`

**Short-Circuiting**: Efficient evaluation stops at first definitive result

- **AND operations**: Stop at first false predicate
- **OR operations**: Stop at first true predicate
- **Performance benefit**: Avoid expensive later computations

**Composition Patterns**: Build complex logic from simple predicates

- **Layered validation**: Basic checks before expensive operations
- **Business rules**: Combine multiple conditions into domain logic
- **Filtering pipelines**: Chain predicates for data processing

## LLM Decision Guide: When to Use Predicates

**✅ Use Predicates when:**

- Need reusable validation logic
- Building complex conditional logic from simple parts
- Want to compose boolean conditions
- Need to filter collections based on multiple criteria
- User says: "validate", "filter", "condition", "check if", "business rules"

**❌ Don't use Predicates when:**

- Simple one-off boolean expressions
- Single validation that won't be reused
- Performance is absolutely critical (function call overhead)
- Logic is too complex for boolean composition

**⚡ Predicate vs. Direct Boolean Decision:**

- **Predicates**: Reusable, composable, testable validation logic
- **Direct booleans**: Simple, one-off conditional checks
- **Rule**: Use predicates when logic will be reused or composed

**⚙️ Function Choice Guide:**

- **`and_all/1`**: All conditions must be true (short-circuits on false)
- **`or_any/1`**: Any condition can be true (short-circuits on true)
- **`not/1`**: Invert a predicate (logical negation)
- **`test/2`**: Apply predicate to value with error handling

## LLM Context Clues

**User language → Predicate patterns:**

- "validate multiple conditions" → `and_all` composition
- "any of these conditions" → `or_any` composition
- "opposite of" or "not" → `not/1` negation
- "business rules" → Complex predicate composition
- "filter by conditions" → Predicate with Enum.filter
- "access control" → Role-based predicate composition
- "data validation" → Layered predicate pipelines
- "conditional logic" → Predicate composition with Utils

## Quick Reference

- **Core concepts**: Functions returning boolean values for conditions
- **Monoid backing**: Uses All (AND) and Any (OR) monoids for composition
- **Main operations**: `and_all/1`, `or_any/1`, `not/1`, `test/2`
- **Performance**: Short-circuiting evaluation for efficiency
- **Composition**: Build complex logic from simple predicate functions

## Overview

`Funx.Predicate` provides utilities for building and composing predicate functions (functions that return boolean values). Predicates are essential for validation, filtering, and conditional logic in functional programming.

The module is backed by monoid operations, enabling composable boolean logic with proper short-circuiting behavior. This makes it efficient and mathematically sound for building complex conditional systems.

## Composition Rules

| Function     | Type Signature                    | Purpose                                     |
| ------------ | --------------------------------- | ------------------------------------------- |
| `and_all/1`  | `[a -> boolean] -> a -> boolean`  | All predicates must be true (AND)          |
| `or_any/1`   | `[a -> boolean] -> a -> boolean`  | Any predicate can be true (OR)             |
| `not/1`      | `(a -> boolean) -> a -> boolean`  | Logical negation of predicate               |
| `test/2`     | `(a -> boolean) -> a -> boolean`  | Apply predicate to value, ensuring boolean result |

These functions enable building complex boolean logic from simple predicate functions while maintaining performance through short-circuiting.

**Monoid Law Guarantees**: Because predicate composition is built on monoids (All and Any), it inherits mathematical guarantees:

- **Associativity**: Grouping doesn't matter - `(p1 AND p2) AND p3 = p1 AND (p2 AND p3)`
- **Identity**: Neutral elements - `and_all([])` returns `fn _ -> true end`, `or_any([])` returns `fn _ -> false end`
- **Short-circuiting**: Efficient evaluation - `and_all` stops at first false, `or_any` stops at first true

**Predicate Arity**: Predicates used in `and_all/1` and `or_any/1` must be unary (1-arity). If more context is needed, use partially applied closures or higher-order predicate factories.

## Predicate DSL

The Predicate DSL is a builder DSL that constructs boolean predicates for later use. See the [DSL guides](../guides/dsl/overview.md) for the distinction between builder and pipeline DSLs.

The DSL provides a declarative syntax for building complex boolean predicates without explicit `p_all`, `p_any`, and `p_not` calls.

**Design Philosophy:**

- **Declarative boolean logic** - Describe what conditions to check, not how to check them
- **Compile-time composition** - DSL expands to static predicate compositions at compile time
- **Boolean structure** - Bare predicates, `negate`, `check`, `all`, `any` directives for flexible logic
- **Type-safe projections** - Leverages Lens and Prism for safe data access in `check` directive

**Key Benefits:**

- Clean, readable multi-condition predicates
- Automatic handling of nil values with Prism semantics
- Explicit Lens for required fields, atoms for optional fields
- Nested `any`/`all` blocks for OR/AND logic
- Zero runtime overhead - compiles to direct function calls
- Works seamlessly with `Enum.filter`, `Enum.find`, and other predicate-accepting functions

### Basic Usage

```elixir
use Funx.Predicate

pred do
  is_adult
  is_verified
end
```

### Practical Comparison: Before and After

**With combinator functions (manual composition):**

```elixir
Predicate.p_all([
  fn user -> user.age >= 18 end,
  fn user -> user.verified end,
  Predicate.p_any([
    fn user -> user.role == :admin end,
    fn user -> user.role == :moderator end
  ])
])
```

**With Predicate DSL (declarative):**

```elixir
pred do
  fn user -> user.age >= 18 end
  fn user -> user.verified end
  any do
    fn user -> user.role == :admin end
    fn user -> user.role == :moderator end
  end
end
```

The DSL version:

- ✅ More readable (clear conditional intent)
- ✅ More concise (no manual p_all/p_any)
- ✅ Type-safe (compile-time validation)
- ✅ Same performance (expands to identical code)

### Directives

- Bare predicate - Include predicate in composition (implicit AND at top level)
- `negate <predicate>` - Negate the predicate (logical NOT)
- `check <projection>, <predicate>` - Compose projection with predicate (check projected value)
- `negate check <projection>, <predicate>` - Negated projection (value must NOT match)
- `any do ... end` - At least one nested predicate must pass (OR logic)
- `all do ... end` - All nested predicates must pass (AND logic, explicit)
- `negate_all do ... end` - NOT (all predicates pass) - applies De Morgan's Laws
- `negate_any do ... end` - NOT (any predicate passes) - applies De Morgan's Laws

### Supported Predicate Forms

**Bare Predicates:**

- `fn user -> user.age >= 18 end` - Anonymous function
- `&adult?/1` - Captured function
- `is_verified` - Variable reference
- `MyModule.adult?()` - Helper function (0-arity, must call with `()`)
- `MyBehaviour` - Behaviour module implementing `Funx.Predicate.Dsl.Behaviour`
- `{MyBehaviour, opt: value}` - Behaviour with options

**Projections (for `check` directive):**

- `check :atom, pred` - Atom field (converts to `Prism.key/1`, degenerate sum: present | absent)
- `check Lens.key(:field), pred` - Explicit Lens (total accessor, raises on missing keys)
- `check Prism.key(:field), pred` - Explicit Prism (branch selector, Nothing fails the predicate)
- `check Prism.struct(Module), pred` - Sum type branch selection (selects one case)
- `check Traversal.combine([...]), pred` - Multiple foci (relates values to each other)
- `check &(&1.field), pred` - Function projection
- `check fn x -> x.field end, pred` - Anonymous function projection

### DSL Examples

**Basic multi-condition predicate:**

```elixir
pred do
  fn user -> user.active end
  fn user -> user.verified end
end
```

**Using negate:**

```elixir
pred do
  fn user -> user.age >= 18 end
  negate fn user -> user.banned end
end
```

**Using check with projections:**

```elixir
pred do
  check :email, fn email -> String.contains?(email, "@") end
  check :age, fn age -> age >= 18 end
end
```

**Using negate check (negated projections):**

```elixir
pred do
  check :age, fn age -> age >= 18 end
  negate check :banned, fn b -> b == true end  # Must NOT be banned
end
```

**OR logic with any blocks:**

```elixir
# Match if user is admin OR moderator
pred do
  any do
    fn user -> user.role == :admin end
    fn user -> user.role == :moderator end
  end
end
```

**Mixed AND/OR logic:**

```elixir
# Active AND (admin OR verified)
pred do
  fn user -> user.active end
  any do
    fn user -> user.role == :admin end
    fn user -> user.verified end
  end
end
```

**Nested blocks:**

```elixir
pred do
  fn user -> user.active end
  any do
    fn user -> user.role == :admin end
    all do
      fn user -> user.verified end
      fn user -> user.age >= 18 end
    end
  end
end
```

**Negating blocks with De Morgan's Laws:**

```elixir
# negate_all - NOT (all conditions pass) = (at least one fails)
# Rejects premium users (adult AND verified AND vip)
pred do
  negate_all do
    fn user -> user.age >= 18 end
    fn user -> user.verified end
    fn user -> user.vip end
  end
end

# negate_any - NOT (any condition passes) = (all fail)
# Regular users only (not vip, not sponsor, not admin)
pred do
  negate_any do
    fn user -> user.vip end
    fn user -> user.sponsor end
    fn user -> user.role == :admin end
  end
end
```

**Using behaviour modules:**

```elixir
defmodule IsActive do
  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts) do
    fn user -> user.active end
  end
end

pred do
  IsActive
  {HasMinimumAge, minimum: 21}
end
```

**Integration with Enum:**

```elixir
check_eligible = pred do
  fn user -> user.age >= 18 end
  fn user -> user.verified end
end

# Filter
Enum.filter(users, check_eligible)

# Find
Enum.find(users, check_eligible)

# Count
Enum.count(users, check_eligible)
```

### When to Use the DSL

**✅ Use the DSL when:**

- Building complex multi-condition predicates
- Need nested AND/OR logic
- Want declarative, readable boolean composition
- Combining projection-based checks with predicates
- Need compile-time validation

**❌ Don't use the DSL when:**

- Simple single predicate (just use the function directly)
- Dynamic predicate construction at runtime
- Performance is absolutely critical (minimal overhead but exists)

### Key Differences from Eq/Ord DSLs

- **No direction field** - Predicates return boolean, not ordering
- **No implicit tiebreaker** - Empty pred block returns `fn _ -> true end`
- **Tree structure** - Nested `all`/`any` blocks for complex boolean logic
- **check directive** - Compose projections with predicates (2 arguments)
- **Different monoids** - `Predicate.All` (AND) and `Predicate.Any` (OR)

### DSL Summary

The Predicate DSL provides declarative multi-condition boolean logic:

**Core Directives:**

- Bare predicate - Must pass (AND)
- `negate <predicate>` - Must fail (NOT)
- `check <projection>, <predicate>` - Project then test
- `negate check <projection>, <predicate>` - Projected value must NOT match
- `any do ... end` - OR logic (at least one must match)
- `all do ... end` - AND logic (all must match)
- `negate_all do ... end` - NOT (all pass) = at least one fails (De Morgan)
- `negate_any do ... end` - NOT (any passes) = all fail (De Morgan)

**Key Patterns:**

- **Atoms** with `check` for optional fields (degenerate sum: present | absent, Nothing fails the predicate)
- **Lens** with `check` for required fields (total accessor, raises on missing keys)
- **Prism** with `check` for sum type branch selection (selects one case, Nothing fails the predicate)
- **Traversal** with `check` for relating multiple foci (collect values to compare or validate together)
- Use behaviour modules for reusable, configurable predicate logic
- Nested `any`/`all` blocks for complex boolean expressions
- Works seamlessly with Enum functions for filtering and searching

## Correct Usage Patterns

### Combining Predicates

```elixir
# Individual predicates
is_adult = fn user -> user.age >= 18 end
has_email = fn user -> String.contains?(user.email, "@") end  
is_active = fn user -> user.active == true end

# Combine with AND (all must be true)
valid_user = Predicate.and_all([is_adult, has_email, is_active])

# Combine with OR (any can be true)  
admin_or_moderator = Predicate.or_any([
  fn user -> user.role == :admin end,
  fn user -> user.role == :moderator end
])

# Test the composed predicates
user = %{age: 25, email: "user@example.com", active: true}
valid_user.(user)  # => true
```

### Working with Lists and Filtering

```elixir
users = [
  %{name: "Alice", age: 30, active: true},
  %{name: "Bob", age: 17, active: true}, 
  %{name: "Carol", age: 25, active: false}
]

# Create filtering predicates
adult_filter = fn user -> user.age >= 18 end
active_filter = fn user -> user.active == true end

# Combine filters
valid_user_filter = Predicate.and_all([adult_filter, active_filter])

# Apply to collection
valid_users = Enum.filter(users, valid_user_filter)
# => [%{name: "Alice", age: 30, active: true}]
```

### Negation

```elixir
# Original predicate
is_admin = fn user -> user.role == :admin end

# Negated predicate
not_admin = Predicate.not(is_admin)

# Use for filtering
regular_users = Enum.filter(all_users, not_admin)
```

## Compositional Guidelines

Follow these patterns when generating or working with predicates:

- **Build from simple parts**: Start with basic predicates and compose them
- **Use descriptive names**: Name intermediate predicates for clarity
- **Layer validations**: Put cheap checks before expensive ones
- **Short-circuit efficiently**: Use `and_all` and `or_any` for performance
- **Avoid side effects**: Keep predicates pure (no IO, mutations, etc.)
- **Test compositions**: Verify complex predicates work as expected

## Stability Contract

Ensure that predicate functions maintain:

- **Purity**: No side effects, same input produces same output
- **Short-circuiting**: `and_all` stops at first false, `or_any` stops at first true  
- **Logical identity**: Follow Boolean algebra laws and De Morgan's laws
- **Type consistency**: All predicates in a composition should accept same type
- **Unary predicates**: All predicates must be single-argument functions for composition

## Anti-Patterns

Avoid generating or emitting:

- **Side effects in predicates**: No IO, logging, or mutations
- **Expensive operations early**: Put cheap validations first
- **Non-boolean returns**: Predicates must return true/false
- **Mixed input types**: Keep predicates type-consistent within compositions
- **Multi-arity predicates**: Don't use predicates requiring multiple arguments in composition
- **Deep nesting**: Use intermediate named predicates instead

## Good Patterns

Encourage completions like:

```elixir
# Named intermediate predicates for clarity
has_permission = fn user -> user.permissions |> Enum.member?(:read) end
within_rate_limit = fn user -> user.requests_today < 100 end
account_active = fn user -> user.status == :active end

# Composed authorization predicate
can_access = Predicate.and_all([has_permission, within_rate_limit, account_active])
```

```elixir
# Proper arity handling for multi-context predicates
# ❌ Wrong: multi-arity predicate
bad_access_check = fn resource, user -> resource.owner_id == user.id end

# ✅ Right: use closure or factory pattern
is_owner = fn resource ->
  fn user -> resource.owner_id == user.id end
end

# ✅ Right: partially applied closure
resource = %{owner_id: 123}
owner_check = is_owner.(resource)  # Returns unary predicate

# Use in composition
access_predicates = Predicate.and_all([
  owner_check,                    # Unary predicate
  fn user -> user.active end,     # Unary predicate
  fn user -> not user.banned end  # Unary predicate
])
```

```elixir
# Efficient layered validation (cheap checks first)
basic_validation = Predicate.and_all([
  fn data -> not is_nil(data.id) end,        # Cheap null check
  fn data -> String.length(data.name) > 0 end # String length check
])

expensive_validation = fn data ->
  # Expensive database check only after basic validation passes
  not Database.user_exists?(data.id)
end

full_validation = Predicate.and_all([basic_validation, expensive_validation])
```

## LLM Code Templates

### Basic Validation Template

```elixir
def build_user_validator() do
  # Define individual validation predicates
  validations = %{
    has_name: fn user -> 
      not is_nil(user.name) and String.length(user.name) > 0 
    end,
    
    valid_email: fn user ->
      String.contains?(user.email, "@") and String.contains?(user.email, ".")
    end,
    
    adult_age: fn user ->
      is_integer(user.age) and user.age >= 18
    end,
    
    active_status: fn user ->
      user.status in [:active, :verified]
    end
  }
  
  # Compose basic validation (cheap checks)
  basic_validation = Predicate.and_all([
    validations.has_name,
    validations.adult_age,
    validations.active_status
  ])
  
  # Compose expensive validation
  expensive_validation = Predicate.and_all([
    validations.valid_email,
    fn user -> not UserRepo.email_exists?(user.email) end  # Database check
  ])
  
  # Final composed validator
  complete_validator = Predicate.and_all([basic_validation, expensive_validation])
  
  # Usage function
  fn user ->
    case complete_validator.(user) do
      true -> {:ok, user}
      false -> {:error, "User validation failed"}
    end
  end
end

# Usage
validator = build_user_validator()
validator.(%{name: "Alice", email: "alice@example.com", age: 25, status: :active})
```

### Access Control Template

```elixir
def build_access_control_system() do
  # Role-based predicates
  roles = %{
    is_admin: fn user -> user.role == :admin end,
    is_moderator: fn user -> user.role == :moderator end,
    is_owner: fn resource, user -> resource.owner_id == user.id end,
    is_collaborator: fn resource, user -> 
      Enum.member?(resource.collaborator_ids, user.id)
    end
  }
  
  # Permission predicates
  permissions = %{
    can_read: fn resource, user ->
      resource.visibility == :public or
      Predicate.or_any([
        roles.is_admin,
        roles.is_owner.(resource),
        roles.is_collaborator.(resource)
      ]).(user)
    end,
    
    can_write: fn resource, user ->
      Predicate.or_any([
        roles.is_admin,
        roles.is_moderator,
        roles.is_owner.(resource)
      ]).(user)
    end,
    
    can_delete: fn resource, user ->
      Predicate.or_any([
        roles.is_admin,
        roles.is_owner.(resource)
      ]).(user)
    end
  }
  
  # Context-aware validation
  def authorize_action(action, resource, user) do
    action_predicate = case action do
      :read -> permissions.can_read.(resource, user)
      :write -> permissions.can_write.(resource, user)
      :delete -> permissions.can_delete.(resource, user)
    end
    
    # Additional context checks
    context_checks = Predicate.and_all([
      fn _ -> user.status == :active end,
      fn _ -> not user.banned end,
      fn _ -> resource.status != :archived end
    ])
    
    final_check = Predicate.and_all([
      fn _ -> action_predicate end,
      context_checks
    ])
    
    final_check.(user)
  end
  
  %{authorize: &authorize_action/3, permissions: permissions, roles: roles}
end
```

### Filtering Pipeline Template

```elixir
def build_data_filtering_pipeline() do
  # Stage 1: Basic data quality filters
  quality_filters = %{
    not_nil: fn item -> not is_nil(item) end,
    has_required_fields: fn item -> 
      [:id, :name, :created_at] |> Enum.all?(fn field -> 
        Map.has_key?(item, field) and not is_nil(item[field])
      end)
    end,
    valid_timestamps: fn item ->
      is_struct(item.created_at, DateTime) and 
      DateTime.compare(item.created_at, DateTime.utc_now()) == :lt
    end
  }
  
  # Stage 2: Business logic filters  
  business_filters = %{
    active_status: fn item -> item.status in [:active, :published] end,
    within_date_range: fn start_date, end_date ->
      fn item ->
        DateTime.compare(item.created_at, start_date) != :lt and
        DateTime.compare(item.created_at, end_date) != :gt
      end
    end,
    meets_threshold: fn threshold_field, min_value ->
      fn item ->
        Map.get(item, threshold_field, 0) >= min_value
      end
    end
  }
  
  # Stage 3: User-specific filters
  user_filters = %{
    user_can_see: fn user ->
      fn item ->
        item.visibility == :public or 
        item.owner_id == user.id or
        user.role in [:admin, :moderator]
      end
    end,
    not_blocked_by_user: fn user ->
      fn item ->
        not Enum.member?(user.blocked_ids || [], item.owner_id)
      end
    end
  }
  
  # Compose filtering pipeline
  def create_filter_pipeline(user, options \\ %{}) do
    # Basic quality checks (always applied)
    basic_quality = Predicate.and_all([
      quality_filters.not_nil,
      quality_filters.has_required_fields,
      quality_filters.valid_timestamps
    ])
    
    # Business logic filters
    business_logic = [
      business_filters.active_status,
      business_filters.within_date_range.(
        options[:start_date] || DateTime.add(DateTime.utc_now(), -30, :day),
        options[:end_date] || DateTime.utc_now()
      ),
      business_filters.meets_threshold.(:score, options[:min_score] || 0)
    ] |> Predicate.and_all()
    
    # User-specific filters
    user_specific = Predicate.and_all([
      user_filters.user_can_see.(user),
      user_filters.not_blocked_by_user.(user)
    ])
    
    # Complete pipeline
    Predicate.and_all([basic_quality, business_logic, user_specific])
  end
  
  # Usage helper
  def filter_data(data_list, user, options \\ %{}) do
    pipeline = create_filter_pipeline(user, options)
    Enum.filter(data_list, pipeline)
  end
  
  %{
    create_pipeline: &create_filter_pipeline/2,
    filter_data: &filter_data/3,
    individual_filters: %{
      quality: quality_filters,
      business: business_filters,
      user: user_filters
    }
  }
end
```

### Business Rules Template

```elixir
def build_business_rules_engine() do
  # Domain-specific predicates
  customer_rules = %{
    is_premium: fn customer -> customer.tier == :premium end,
    account_in_good_standing: fn customer -> 
      customer.balance >= 0 and customer.past_due_count < 3
    end,
    region_eligible: fn allowed_regions ->
      fn customer -> Enum.member?(allowed_regions, customer.region) end
    end,
    loyalty_member: fn min_months ->
      fn customer ->
        months_active = DateTime.diff(DateTime.utc_now(), customer.signup_date, :day) / 30
        months_active >= min_months
      end
    end
  }
  
  order_rules = %{
    within_limits: fn customer ->
      fn order ->
        daily_total = CustomerService.daily_order_total(customer.id)
        (daily_total + order.amount) <= customer.daily_limit
      end
    end,
    valid_items: fn order ->
      Enum.all?(order.items, fn item ->
        item.quantity > 0 and item.price > 0 and not item.discontinued
      end)
    end,
    shipping_available: fn order ->
      ShippingService.can_ship_to?(order.shipping_address)
    end
  }
  
  # Compose complex business rules
  def create_order_validation_rules(promotions \\ []) do
    # Base eligibility rules
    customer_eligible = Predicate.and_all([
      customer_rules.account_in_good_standing,
      customer_rules.region_eligible.([:us, :ca, :uk])
    ])
    
    # Order validation rules
    order_valid = Predicate.and_all([
      order_rules.valid_items,
      order_rules.shipping_available
    ])
    
    # Dynamic promotion rules
    promotion_rules = promotions
    |> Enum.map(fn promo ->
      case promo.type do
        :loyalty -> 
          customer_rules.loyalty_member.(promo.min_months)
        :premium -> 
          customer_rules.is_premium
        :volume ->
          fn customer -> 
            fn order -> 
              order.amount >= promo.min_amount
            end
          end
      end
    end)
    |> Predicate.or_any()  # Any promotion can apply
    
    # Combine all rules
    %{
      can_place_order: fn customer, order ->
        basic_rules = Predicate.and_all([
          fn _ -> customer_eligible.(customer) end,
          fn _ -> order_valid.(order) end,
          order_rules.within_limits.(customer)
        ])
        basic_rules.(order)
      end,
      
      eligible_for_promotions: fn customer, order ->
        promotion_check = promotion_rules.(customer)
        promotion_check.(order)
      end,
      
      complete_validation: fn customer, order ->
        all_rules = Predicate.and_all([
          fn _ -> customer_eligible.(customer) end,
          fn _ -> order_valid.(order) end,
          order_rules.within_limits.(customer)
        ])
        
        {all_rules.(order), promotion_rules.(customer).(order)}
      end
    }
  end
  
  %{
    customer_rules: customer_rules,
    order_rules: order_rules,
    create_validation: &create_order_validation_rules/1
  }
end
```

## LLM Performance Considerations

### Short-Circuiting Behavior

```elixir
# ✅ Good: Cheap predicates first
efficient_validation = Predicate.and_all([
  fn user -> not is_nil(user.id) end,           # Very fast
  fn user -> String.length(user.email) > 5 end, # Fast
  fn user -> Database.user_exists?(user.id) end  # Expensive - last
])

# ❌ Less efficient: Expensive predicate first
inefficient_validation = Predicate.and_all([
  fn user -> Database.user_exists?(user.id) end, # Expensive - runs every time
  fn user -> not is_nil(user.id) end            # Fast - but too late
])
```

### Predicate Memoization

```elixir
# For expensive predicates that are reused
def create_memoized_predicate(expensive_fn) do
  cache = Agent.start_link(fn -> %{} end)
  
  fn input ->
    Agent.get_and_update(cache, fn state ->
      case Map.get(state, input) do
        nil -> 
          result = expensive_fn.(input)
          {result, Map.put(state, input, result)}
        cached_result -> 
          {cached_result, state}
      end
    end)
  end
end

# Usage
expensive_check = create_memoized_predicate(fn user -> 
  # Expensive operation here
  ExternalAPI.validate_user(user.id)
end)

validation = Predicate.and_all([basic_checks, expensive_check])
```

## LLM Interop Patterns

### With Funx.Utils

```elixir
def build_utils_integration() do
  # Create predicate functions for pipeline use
  # Note: Predicates are functions that can be called directly
  
  # Create reusable predicates
  test_adult = fn user -> user.age >= 18 end
  test_active = fn user -> user.status == :active end
  test_verified = fn user -> user.verified == true end
  
  # Use in pipelines
  users = [%{age: 25, status: :active, verified: true}, %{age: 17, status: :inactive, verified: false}]
  
  adults = users |> Enum.filter(test_adult)
  active_users = users |> Enum.filter(test_active)
  
  # Compose with other Utils functions
  filter_by = Funx.Utils.flip(&Enum.filter/2)
  
  # Create specialized filters
  filter_adults = filter_by.(test_adult)
  filter_active = filter_by.(test_active)
  
  users 
  |> filter_adults.()
  |> filter_active.()
end
```

### With Maybe/Either Bind

```elixir
def build_monadic_validation() do
  # Convert predicates to Maybe-returning validators
  def predicate_to_maybe(predicate, error_msg) do
    fn value ->
      if predicate.(value) do
        Maybe.just(value)
      else
        Maybe.nothing()
      end
    end
  end
  
  # Convert predicates to Either-returning validators
  def predicate_to_either(predicate, error_msg) do
    fn value ->
      if predicate.(value) do
        Either.right(value)
      else
        Either.left(error_msg)
      end
    end
  end
  
  # Create validators
  age_predicate = fn user -> user.age >= 18 end
  email_predicate = fn user -> String.contains?(user.email, "@") end
  
  age_validator = predicate_to_either(age_predicate, "Must be adult")
  email_validator = predicate_to_either(email_predicate, "Invalid email")
  
  # Use in monadic pipeline
  def validate_user(user) do
    Either.right(user)
    |> Either.bind(age_validator)
    |> Either.bind(email_validator)
  end
  
  validate_user(%{age: 25, email: "user@example.com"})  # Right(user)
  validate_user(%{age: 16, email: "invalid"})          # Left("Must be adult")
end
```

### With Enum Functions

```elixir
def build_enum_integration() do
  # Predicate-based collection operations
  
  users = [
    %{name: "Alice", role: :admin, active: true},
    %{name: "Bob", role: :user, active: false}, 
    %{name: "Carol", role: :moderator, active: true}
  ]
  
  # Create predicates
  is_admin = fn user -> user.role == :admin end
  is_active = fn user -> user.active == true end
  is_staff = Predicate.or_any([
    fn user -> user.role == :admin end,
    fn user -> user.role == :moderator end
  ])
  
  # Use with Enum functions
  active_users = Enum.filter(users, is_active)
  staff_members = Enum.filter(users, is_staff)
  
  # Combine predicates for complex filtering
  active_staff = Enum.filter(users, Predicate.and_all([is_staff, is_active]))
  
  # Partition based on predicates
  {staff, regular_users} = Enum.split_with(users, is_staff)
  
  # Count matching items
  staff_count = Enum.count(users, is_staff)
  
  # Find items
  first_admin = Enum.find(users, is_admin)
  all_active = Enum.all?(users, is_active)
  any_admins = Enum.any?(users, is_admin)
  
  %{
    active_users: active_users,
    staff_members: staff_members,
    active_staff: active_staff,
    counts: %{staff: staff_count},
    checks: %{all_active: all_active, any_admins: any_admins}
  }
end
```

### With Case Statements

```elixir
def build_case_integration() do
  # Use predicates in case statement guards
  
  is_admin = fn user -> user.role == :admin end
  is_owner = fn resource, user -> resource.owner_id == user.id end
  is_collaborator = fn resource, user -> 
    Enum.member?(resource.collaborators, user.id)
  end
  
  def authorize_action(action, resource, user) do
    case {action, is_admin.(user)} do
      {_, true} -> 
        # Admins can do anything
        :authorized
        
      {:read, false} ->
        # Non-admins need specific read permissions
        case Predicate.or_any([is_owner.(resource), is_collaborator.(resource)]).(user) do
          true -> :authorized
          false -> {:unauthorized, "No read access"}
        end
        
      {:write, false} ->
        # Non-admins need ownership for writes
        case is_owner.(resource).(user) do
          true -> :authorized
          false -> {:unauthorized, "Must be owner to modify"}
        end
        
      {:delete, false} ->
        # Only owners and admins can delete
        {:unauthorized, "Insufficient permissions for delete"}
    end
  end
  
  %{authorize: &authorize_action/3}
end
```

### With Guard Clauses

```elixir
def build_guard_integration() do
  # Convert predicates to guard-compatible expressions
  
  # Note: These need to be guard-safe functions
  def process_user(user) when user.age >= 18 and user.active == true do
    {:ok, "Processing adult active user: #{user.name}"}
  end
  
  def process_user(user) when user.role == :admin do
    {:ok, "Processing admin user: #{user.name}"}
  end
  
  def process_user(_user) do
    {:error, "User does not meet processing criteria"}
  end
  
  # For more complex predicates, use function heads
  def handle_request(request, user) do
    cond do
      is_admin_user().(user) ->
        handle_admin_request(request, user)
        
      is_premium_user().(user) ->
        handle_premium_request(request, user)
        
      basic_user_requirements().(user) ->
        handle_basic_request(request, user)
        
      true ->
        {:error, "User not authorized for any request type"}
    end
  end
  
  defp is_admin_user(), do: fn user -> user.role == :admin end
  defp is_premium_user(), do: fn user -> user.subscription == :premium end
  defp basic_user_requirements() do
    Predicate.and_all([
      fn user -> user.verified == true end,
      fn user -> user.status == :active end
    ])
  end
  
  %{process_user: &process_user/1, handle_request: &handle_request/2}
end
```

## LLM Testing Guidance

### Test Individual Predicates

```elixir
defmodule PredicateTest do
  use ExUnit.Case
  
  test "individual predicates work correctly" do
    is_adult = fn user -> user.age >= 18 end
    has_email = fn user -> String.contains?(user.email, "@") end
    
    adult_user = %{age: 25, email: "user@example.com"}
    minor_user = %{age: 16, email: "teen@example.com"}
    
    assert is_adult.(adult_user) == true
    assert is_adult.(minor_user) == false
    
    assert has_email.(adult_user) == true
    assert has_email.(%{age: 25, email: "invalid"}) == false
  end
  
  test "predicate composition works" do
    is_adult = fn user -> user.age >= 18 end
    has_email = fn user -> String.contains?(user.email, "@") end
    is_active = fn user -> user.active == true end
    
    # Test AND composition
    valid_user = Predicate.and_all([is_adult, has_email, is_active])
    
    fully_valid = %{age: 25, email: "user@example.com", active: true}
    invalid_email = %{age: 25, email: "invalid", active: true}
    inactive_user = %{age: 25, email: "user@example.com", active: false}
    
    assert valid_user.(fully_valid) == true
    assert valid_user.(invalid_email) == false
    assert valid_user.(inactive_user) == false
    
    # Test OR composition  
    admin_or_owner = Predicate.or_any([
      fn user -> user.role == :admin end,
      fn user -> user.owner == true end
    ])
    
    admin_user = %{role: :admin, owner: false}
    owner_user = %{role: :user, owner: true}
    regular_user = %{role: :user, owner: false}
    
    assert admin_or_owner.(admin_user) == true
    assert admin_or_owner.(owner_user) == true
    assert admin_or_owner.(regular_user) == false
  end
  
  test "predicate negation works" do
    is_admin = fn user -> user.role == :admin end
    is_not_admin = Predicate.not(is_admin)
    
    admin_user = %{role: :admin}
    regular_user = %{role: :user}
    
    assert is_admin.(admin_user) == true
    assert is_not_admin.(admin_user) == false
    
    assert is_admin.(regular_user) == false
    assert is_not_admin.(regular_user) == true
  end
end
```

### Test Composed Predicates

```elixir
defmodule ComposedPredicateTest do
  use ExUnit.Case
  
  setup do
    users = [
      %{name: "Alice", age: 30, role: :admin, active: true, verified: true},
      %{name: "Bob", age: 17, role: :user, active: true, verified: false},
      %{name: "Carol", age: 25, role: :moderator, active: false, verified: true},
      %{name: "Dave", age: 35, role: :user, active: true, verified: true}
    ]
    
    {:ok, users: users}
  end
  
  test "complex business rule validation", %{users: users} do
    # Build complex business rules
    basic_requirements = Predicate.and_all([
      fn user -> user.age >= 18 end,
      fn user -> user.active == true end,
      fn user -> user.verified == true end
    ])
    
    elevated_access = Predicate.or_any([
      fn user -> user.role == :admin end,
      fn user -> user.role == :moderator end
    ])
    
    can_moderate = Predicate.and_all([basic_requirements, elevated_access])
    
    # Test against known data
    [alice, bob, carol, dave] = users
    
    assert can_moderate.(alice) == true   # Admin, meets requirements
    assert can_moderate.(bob) == false    # Minor, unverified
    assert can_moderate.(carol) == false  # Inactive
    assert can_moderate.(dave) == false   # No elevated role
  end
  
  test "filtering with composed predicates", %{users: users} do
    # Create filtering predicates
    is_adult = fn user -> user.age >= 18 end
    is_staff = Predicate.or_any([
      fn user -> user.role == :admin end,
      fn user -> user.role == :moderator end
    ])
    
    active_staff = Predicate.and_all([
      is_adult,
      is_staff,
      fn user -> user.active == true end
    ])
    
    result = Enum.filter(users, active_staff)
    
    # Only Alice should match (adult, admin, active)
    assert length(result) == 1
    assert hd(result).name == "Alice"
  end
  
  test "short-circuiting behavior" do
    call_count = Agent.start_link(fn -> 0 end, name: :test_counter)
    
    expensive_predicate = fn _user ->
      Agent.update(:test_counter, &(&1 + 1))
      true
    end
    
    # This should short-circuit after the first false
    short_circuit_predicate = Predicate.and_all([
      fn _user -> false end,  # Always false - should short-circuit here
      expensive_predicate    # Should not be called
    ])
    
    user = %{name: "Test"}
    result = short_circuit_predicate.(user)
    call_count_after = Agent.get(:test_counter, & &1)
    
    assert result == false
    assert call_count_after == 0  # Expensive predicate was not called
  end
end
```

### Test Edge Cases

```elixir
defmodule PredicateEdgeCaseTest do
  use ExUnit.Case
  
  test "empty predicate lists" do
    # Empty and_all should return true (identity element)
    always_true = Predicate.and_all([])
    assert always_true.(:anything) == true
    
    # Empty or_any should return false (identity element)
    always_false = Predicate.or_any([])
    assert always_false.(:anything) == false
  end
  
  test "single predicate in composition" do
    single_pred = fn x -> x > 5 end
    
    and_single = Predicate.and_all([single_pred])
    or_single = Predicate.or_any([single_pred])
    
    assert and_single.(10) == true
    assert or_single.(10) == true
    assert and_single.(3) == false
    assert or_single.(3) == false
  end
  
  test "nested composition" do
    # Build nested predicate structure
    inner_and = Predicate.and_all([
      fn x -> x > 0 end,
      fn x -> x < 100 end
    ])
    
    inner_or = Predicate.or_any([
      fn x -> x == -1 end,  # Special case
      inner_and             # Or within normal range
    ])
    
    outer_predicate = Predicate.and_all([
      fn x -> is_integer(x) end,
      inner_or
    ])
    
    assert outer_predicate.(50) == true    # Integer in range
    assert outer_predicate.(-1) == true    # Special case
    assert outer_predicate.(150) == false  # Out of range
    assert outer_predicate.(5.5) == false  # Not integer
  end
  
  test "nil and error handling" do
    safe_predicate = fn user ->
      # Safely handle potential nil values
      not is_nil(user) and 
      Map.has_key?(user, :age) and 
      not is_nil(user.age) and
      user.age >= 18
    end
    
    assert safe_predicate.(%{age: 25}) == true
    assert safe_predicate.(%{}) == false
    assert safe_predicate.(nil) == false
  end
end
```

## LLM Debugging Tips

### Named Predicates for Clarity

```elixir
def build_debuggable_predicates() do
  # Create named predicates for easier debugging
  predicates = %{
    is_adult: fn user -> 
      result = user.age >= 18
      IO.puts("is_adult(#{user.name}): #{result}")
      result
    end,
    
    has_valid_email: fn user ->
      result = String.contains?(user.email, "@")
      IO.puts("has_valid_email(#{user.name}): #{result}")
      result
    end,
    
    is_active: fn user ->
      result = user.active == true
      IO.puts("is_active(#{user.name}): #{result}")  
      result
    end
  }
  
  # Compose with logging
  user_validator = Predicate.and_all([
    predicates.is_adult,
    predicates.has_valid_email,
    predicates.is_active
  ])
  
  # Test user
  test_user = %{name: "Alice", age: 25, email: "alice@test.com", active: true}
  
  IO.puts("Testing user validation:")
  result = user_validator.(test_user)
  IO.puts("Final result: #{result}")
  
  result
end
```

### Component Testing

```elixir
def debug_predicate_composition() do
  # Test individual components first
  predicates = [
    {"age_check", fn user -> user.age >= 18 end},
    {"email_check", fn user -> String.contains?(user.email, "@") end},
    {"active_check", fn user -> user.active == true end}
  ]
  
  test_user = %{name: "Bob", age: 17, email: "bob@test.com", active: false}
  
  IO.puts("Individual predicate results:")
  individual_results = predicates
  |> Enum.map(fn {name, pred} ->
    result = pred.(test_user)
    IO.puts("#{name}: #{result}")
    {name, result}
  end)
  
  # Test composition
  composed = predicates |> Enum.map(fn {_, pred} -> pred end) |> Predicate.p_all()
  composed_result = composed.(test_user)
  
  IO.puts("Composed result: #{composed_result}")
  
  # Analyze results
  failing_predicates = individual_results 
  |> Enum.filter(fn {_, result} -> not result end)
  |> Enum.map(fn {name, _} -> name end)
  
  IO.puts("Failing predicates: #{inspect(failing_predicates)}")
  
  %{individual: individual_results, composed: composed_result, failing: failing_predicates}
end
```

## LLM Error Message Design

### Providing Context for Failures

```elixir
def build_descriptive_validation() do
  # Create predicates with error context
  def create_validating_predicate(predicate_fn, description) do
    fn value ->
      case predicate_fn.(value) do
        true -> {:ok, value}
        false -> {:error, "#{description} failed for #{inspect(value)}"}
      end
    end
  end
  
  # Build contextual validators
  validators = %{
    age_validator: create_validating_predicate(
      fn user -> user.age >= 18 end,
      "Age requirement (>=18)"
    ),
    
    email_validator: create_validating_predicate(
      fn user -> String.contains?(user.email, "@") end,
      "Email format validation"
    ),
    
    status_validator: create_validating_predicate(
      fn user -> user.status == :active end,
      "Active status requirement"
    )
  }
  
  # Compose with error accumulation
  def validate_user_with_errors(user) do
    results = [
      validators.age_validator.(user),
      validators.email_validator.(user),
      validators.status_validator.(user)
    ]
    
    errors = results 
    |> Enum.filter(fn result -> elem(result, 0) == :error end)
    |> Enum.map(fn {:error, msg} -> msg end)
    
    case errors do
      [] -> {:ok, user}
      error_list -> {:error, "Validation failed: " <> Enum.join(error_list, ", ")}
    end
  end
  
  %{validate: &validate_user_with_errors/1}
end
```

## LLM Common Mistakes to Avoid

### ❌ Don't Use Side Effects in Predicates

```elixir
# ❌ Wrong: predicates with side effects
bad_predicate = fn user ->
  Logger.info("Checking user #{user.id}")  # Side effect!
  Database.log_access(user.id)             # Side effect!
  user.age >= 18
end

# ✅ Correct: pure predicates, side effects elsewhere
good_predicate = fn user -> user.age >= 18 end

def validate_and_log(user) do
  Logger.info("Checking user #{user.id}")    # Side effects separate
  is_valid = good_predicate.(user)
  if is_valid, do: Database.log_access(user.id)
  is_valid
end
```

### ❌ Don't Put Expensive Operations First

```elixir
# ❌ Wrong: expensive check first
inefficient_validation = Predicate.and_all([
  fn user -> ExternalAPI.verify_identity(user.ssn) end,  # Expensive!
  fn user -> not is_nil(user.name) end,                  # Cheap
  fn user -> String.length(user.email) > 0 end          # Cheap  
])

# ✅ Correct: cheap checks first, expensive last
efficient_validation = Predicate.and_all([
  fn user -> not is_nil(user.name) end,                  # Cheap first
  fn user -> String.length(user.email) > 0 end,         # Still cheap
  fn user -> ExternalAPI.verify_identity(user.ssn) end  # Expensive last
])
```

### ❌ Don't Return Non-Boolean Values

```elixir
# ❌ Wrong: returning non-boolean
bad_predicate = fn user ->
  case user.age do
    age when age >= 18 -> :adult
    age when age >= 13 -> :teen  
    _ -> :child
  end
end

# ✅ Correct: always return boolean
good_adult_predicate = fn user -> user.age >= 18 end
good_teen_predicate = fn user -> user.age >= 13 and user.age < 18 end

# If you need the classification, use a separate function
def classify_user(user) do
  cond do
    good_adult_predicate.(user) -> :adult
    good_teen_predicate.(user) -> :teen
    true -> :child
  end
end
```

### ❌ Don't Mix Types in Composition

```elixir
# ❌ Wrong: predicates expecting different types  
mixed_predicates = Predicate.and_all([
  fn user -> user.age >= 18 end,           # Expects user struct
  fn name -> String.length(name) > 0 end   # Expects string
])

# ✅ Correct: consistent input types
user_predicates = Predicate.and_all([
  fn user -> user.age >= 18 end,
  fn user -> String.length(user.name) > 0 end,  # Extract field first
  fn user -> not is_nil(user.email) end
])
```

### ❌ Don't Ignore Error Cases

```elixir
# ❌ Wrong: not handling potential errors
unsafe_predicate = fn user ->
  user.profile.preferences.notifications.email == true  # Could crash!
end

# ✅ Correct: safe field access
safe_predicate = fn user ->
  get_in(user, [:profile, :preferences, :notifications, :email]) == true
end

# ✅ Even better: with nil checks
better_predicate = fn user ->
  case get_in(user, [:profile, :preferences, :notifications, :email]) do
    true -> true
    _ -> false
  end
end
```

### ❌ Don't Create Overly Complex Single Predicates

```elixir
# ❌ Wrong: overly complex single predicate
complex_predicate = fn user ->
  user.age >= 18 and 
  user.active == true and
  user.verified == true and
  String.contains?(user.email, "@") and
  user.role in [:admin, :moderator, :user] and
  length(user.permissions) > 0 and
  not is_nil(user.last_login) and
  DateTime.diff(DateTime.utc_now(), user.last_login, :day) <= 30
end

# ✅ Correct: break down into composable parts
basic_checks = Predicate.and_all([
  fn user -> user.age >= 18 end,
  fn user -> user.active == true end,
  fn user -> user.verified == true end
])

account_checks = Predicate.and_all([
  fn user -> String.contains?(user.email, "@") end,
  fn user -> user.role in [:admin, :moderator, :user] end,
  fn user -> length(user.permissions) > 0 end
])

activity_checks = Predicate.and_all([
  fn user -> not is_nil(user.last_login) end,
  fn user -> DateTime.diff(DateTime.utc_now(), user.last_login, :day) <= 30 end
])

complete_validation = Predicate.and_all([basic_checks, account_checks, activity_checks])
```

## LLM Integration with Monoids

Understanding the monoid connection helps with advanced predicate composition:

```elixir
# Predicates use All and Any monoids internally
def demonstrate_monoid_connection() do
  # All monoid (AND behavior) - identity is true
  all_monoid_example = Predicate.and_all([
    fn x -> x > 0 end,    # First check
    fn x -> x < 100 end   # Second check  
  ])
  # Equivalent to: All.concat([predicate1, predicate2])
  
  # Any monoid (OR behavior) - identity is false  
  any_monoid_example = Predicate.or_any([
    fn x -> x == :admin end,     # First check
    fn x -> x == :moderator end  # Second check
  ])
  # Equivalent to: Any.concat([predicate1, predicate2])
  
  # Direct monoid usage (advanced)
  alias Funx.Monoid.All
  alias Funx.Monoid.Any
  
  # Build using monoids directly
  manual_all = All.concat([
    All.new(fn x -> x > 0 end),
    All.new(fn x -> x < 100 end)
  ])
  
  manual_any = Any.concat([
    Any.new(fn x -> x == :admin end),
    Any.new(fn x -> x == :moderator end)
  ])
  
  # Extract predicates from monoids
  all_pred = All.get_value(manual_all)
  any_pred = Any.get_value(manual_any)
  
  %{
    standard_and: all_monoid_example,
    standard_or: any_monoid_example,
    manual_all: all_pred,
    manual_any: any_pred
  }
end
```

## Summary

`Funx.Predicate` provides composable boolean logic for validation, filtering, and conditional operations. It's built on solid mathematical foundations with monoid backing for efficient composition.

**Key capabilities:**

- **Composable validation**: Build complex logic from simple predicates
- **Monoid-backed operations**: Mathematically sound with proper identity elements
- **Short-circuiting evaluation**: Efficient `and_all` and `or_any` operations
- **Cross-module integration**: Works seamlessly with Utils, Maybe, Either, and Enum
- **Performance optimization**: Put cheap predicates first for efficiency

**Core patterns:**

- Use `and_all/1` when all conditions must be true
- Use `or_any/1` when any condition can be true  
- Use `not/1` for logical negation
- Compose predicates rather than building complex single functions
- Order predicates from cheapest to most expensive

**Integration points:**

- **Utils**: Curry predicates for pipeline use
- **Monads**: Convert predicates to Maybe/Either validators
- **Collections**: Use with Enum filtering and testing functions
- **Monoids**: Direct monoid usage for advanced composition patterns

**Canon**: Build from simple predicates, compose with monoid operations, optimize with short-circuiting, integrate across functional abstractions.
