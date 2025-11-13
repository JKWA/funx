# `Funx.Monad.Reader` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Reader**: Represents deferred computation with read-only environment access

- `pure(value)` creates a Reader that ignores environment, returns value
- `run(reader, env)` executes the deferred computation with environment
- `asks/1` extracts and transforms environment data
- `ask/0` extracts full environment unchanged

**Deferred Computation**: Define now, run later with environment

- Reader describes computation steps but doesn't execute until `run/2`
- **Lazy evaluation**: Nothing happens until environment is supplied
- **Thunk pattern**: Functions that defer computation until needed

**Environment Threading**: Read-only context passed through computation chain

- Environment flows through `map/2`, `bind/2`, `ap/2` automatically
- Each step can access environment via `asks/1` without explicit passing
- **Key insight**: Eliminates prop drilling and explicit parameter passing

## LLM Decision Guide: When to Use Reader

### Use Reader For

- **Dependency injection** - swap implementations without changing logic
- **Configuration access** - shared settings across computation chain
- **Avoiding prop drilling** - deep access without threading parameters
- **Environment-dependent logic** - computation that varies by context

### Don't Use Reader For

- **State modification** - Reader is read-only (use Writer or State)
- **Error handling** - Reader doesn't short-circuit (use Either)
- **Optional values** - Reader always requires environment (use Maybe)
- **Simple value transformation** - Reader adds unnecessary complexity

## Core Patterns

### Construction and Execution

```elixir
import Funx.Monad, only: [map: 2, bind: 2, ap: 2]

# Create Reader with pure value
reader = Reader.pure(42)
Reader.run(reader, env)  # 42

# Create Reader that uses environment  
reader = Reader.asks(fn env -> env.api_key end)
Reader.run(reader, %{api_key: "secret"})  # "secret"

# Access full environment
reader = Reader.ask()
Reader.run(reader, %{foo: "bar"})  # %{foo: "bar"}
```

### Dependency Injection Pattern

```elixir
# Define services
prod_service = fn name -> "Hello #{name} from production!" end
test_service = fn name -> "Hello #{name} from test!" end

# Create computation that depends on injected service
greet_user = fn user ->
  Reader.asks(fn service -> service.(user.name) end)
end

# Build deferred computation
user = %{name: "Alice"}
greeting = greet_user.(user)

# Inject different services
Reader.run(greeting, prod_service)  # "Hello Alice from production!"
Reader.run(greeting, test_service)  # "Hello Alice from test!"
```

### Configuration Access Pattern

```elixir
# Configuration-dependent computation
create_api_client = Reader.asks(fn config ->
  %ApiClient{
    endpoint: config.api_endpoint,
    timeout: config.timeout,
    retries: config.max_retries
  }
end)

# Use configuration
config = %{api_endpoint: "https://api.example.com", timeout: 5000, max_retries: 3}
client = Reader.run(create_api_client, config)
```

### Avoid Prop Drilling Pattern

```elixir
# Without Reader (prop drilling)
square_tunnel = fn {n, user} -> {n * user} end
format_result = fn {n, user} -> "#{user.name} has #{n}" end

{4, user} |> square_tunnel.() |> format_result.()

# With Reader (clean separation)
square = fn n -> n * n end
format_with_user = fn n ->
  Reader.asks(fn user -> "#{user.name} has #{n}" end)
end

Reader.pure(4)
|> map(square)
|> bind(format_with_user)
|> Reader.run(user)  # "Alice has 16"
```

## Key Rules

- **PURE for values** - Use `Reader.pure/1` for environment-independent values
- **ASKS for environment** - Use `Reader.asks/1` to access and transform environment
- **RUN to execute** - Always call `Reader.run/2` to resolve deferred computation
- **LAZY execution** - Reader describes steps, nothing happens until run
- **READ-ONLY access** - Environment cannot be modified, only read
- **NO comparison** - Reader doesn't implement Eq/Ord (no meaningful comparison of deferred computations)

## Monadic Composition

### Sequential Computation (bind)

```elixir
# Chain Reader computations that depend on previous results
fetch_user_config = fn user_id ->
  Reader.asks(fn db -> Database.get_user_config(db, user_id) end)
end

apply_defaults = fn config ->
  Reader.asks(fn defaults -> Map.merge(defaults, config) end)
end

# Chain operations
user_id = 123
final_config = Reader.pure(user_id)
|> bind(fetch_user_config)
|> bind(apply_defaults)

# Execute with environment
env = %{db: database, defaults: %{theme: "dark", lang: "en"}}
config = Reader.run(final_config, env)
```

### Parallel Computation (ap)

**Note**: `ap/2` applies a wrapped function to a wrapped value, threading environment through both.

```elixir
# Combine multiple Reader computations
get_name = Reader.asks(fn user -> user.name end)
get_email = Reader.asks(fn user -> user.email end)
format_contact = Reader.pure(fn name -> fn email -> "#{name} <#{email}>" end end)

# Apply pattern for parallel access
contact = format_contact
|> ap(get_name)
|> ap(get_email)

user = %{name: "Alice", email: "alice@example.com"}
Reader.run(contact, user)  # "Alice <alice@example.com>"
```

### Transformation (map)

```elixir
# Transform Reader results
get_age = Reader.asks(fn user -> user.age end)
categorize_age = fn age ->
  cond do
    age < 18 -> :minor
    age < 65 -> :adult
    true -> :senior
  end
end

age_category = get_age |> map(categorize_age)
Reader.run(age_category, %{age: 25})  # :adult
```

## Advanced Patterns

### Nested Environment Access

```elixir
# Access nested configuration
get_db_config = Reader.asks(fn env -> env.database.connection_string end)
get_cache_config = Reader.asks(fn env -> env.cache.redis_url end)

# Combine nested access
setup_services = ap(
  Reader.pure(fn db -> fn cache -> %{database: db, cache: cache} end end),
  get_db_config
) |> ap(get_cache_config)

env = %{
  database: %{connection_string: "postgres://..."},
  cache: %{redis_url: "redis://..."}
}
services = Reader.run(setup_services, env)
```

### Conditional Logic with Environment

```elixir
# Environment-dependent branching
get_feature_flag = fn feature ->
  Reader.asks(fn env -> Map.get(env.features, feature, false) end)
end

conditional_processing = fn data ->
  get_feature_flag.(:use_new_algorithm)
  |> bind(fn enabled ->
    if enabled do
      Reader.pure(new_algorithm(data))
    else  
      Reader.pure(legacy_algorithm(data))
    end
  end)
end

# Usage
env = %{features: %{use_new_algorithm: true}}
result = conditional_processing.(data) |> Reader.run(env)
```

### Reader Composition

```elixir
# Compose Readers for complex workflows
authenticate_user = fn credentials ->
  Reader.asks(fn auth_service -> auth_service.verify(credentials) end)
end

authorize_action = fn user, action ->
  Reader.asks(fn authz_service -> authz_service.can?(user, action) end)
end

fetch_data = fn query ->
  Reader.asks(fn db -> db.query(query) end)
end

# Compose into workflow
secure_data_access = fn credentials, action, query ->
  authenticate_user.(credentials)
  |> bind(fn user -> authorize_action.(user, action))
  |> bind(fn _authorized -> fetch_data.(query))
end

# Execute with services
services = %{
  auth_service: auth_service,
  authz_service: authz_service, 
  db: database
}
data = Reader.run(secure_data_access.(creds, :read, "SELECT * FROM users"), services)
```

## Integration with Other Monads

### Reader + Either (Error Handling)

```elixir
# Reader that might fail
safe_divide = fn x, y ->
  Reader.asks(fn precision ->
    if y == 0 do
      Either.left("Division by zero")
    else
      Either.right(Float.round(x / y, precision))
    end
  end)
end

# Chain Reader and Either
result = Reader.run(safe_divide.(10, 3), 2)  # Either.right(3.33)
```

### Reader + Maybe (Optional Values)

```elixir
# Reader with optional results
lookup_config = fn key ->
  Reader.asks(fn config ->
    case Map.get(config, key) do
      nil -> Maybe.nothing()
      value -> Maybe.just(value)
    end
  end)
end

# Usage
config = %{timeout: 5000}
timeout = Reader.run(lookup_config.(:timeout), config)  # Maybe.just(5000)
missing = Reader.run(lookup_config.(:retries), config)  # Maybe.nothing()
```

## Testing Patterns

```elixir
# Test Reader computations by providing mock environments
test "dependency injection with Reader" do
  mock_service = fn name -> "Mock greeting for #{name}" end
  real_service = fn name -> "Real greeting for #{name}" end
  
  greet = fn name ->
    Reader.asks(fn service -> service.(name) end)
  end
  
  greeting_reader = greet.("Alice")
  
  # Test with mock
  assert Reader.run(greeting_reader, mock_service) == "Mock greeting for Alice"
  
  # Test with real service  
  assert Reader.run(greeting_reader, real_service) == "Real greeting for Alice"
end

# Test configuration access
test "configuration-dependent behavior" do
  process_data = fn data ->
    Reader.asks(fn config ->
      if config.debug do
        "Debug: processing #{inspect(data)}"
      else
        "Processing data"
      end
    end)
  end
  
  processor = process_data.(%{id: 1})
  
  debug_config = %{debug: true}
  prod_config = %{debug: false}
  
  assert Reader.run(processor, debug_config) == "Debug: processing %{id: 1}"
  assert Reader.run(processor, prod_config) == "Processing data"
end
```

## Anti-Patterns

```elixir
# L Don't modify environment (Reader is read-only)
bad_reader = Reader.asks(fn env -> 
  Map.put(env, :modified, true)  # Environment change won't persist!
end)

# L Don't use Reader for error handling
bad_error_handling = Reader.asks(fn env ->
  if env.error?, do: raise("Error!"), else: "Success"  # Use Either instead
end)

# L Don't nest Reader.run calls unnecessarily
bad_nesting = fn env ->
  inner = Reader.pure(42)
  Reader.run(inner, env)  # Unnecessary - just use 42 directly
end

# L Don't compare Readers directly
reader1 = Reader.pure(42)  
reader2 = Reader.pure(42)
# reader1 == reader2  # Won't work - Readers don't implement Eq

#  Compare results instead
env = %{}
Reader.run(reader1, env) == Reader.run(reader2, env)  # true
```

## Performance Considerations

- Reader computations are lazy - no work until `run/2`
- Environment is passed through entire computation chain
- Large environments may impact memory usage
- Consider using focused `asks/1` to extract only needed data
- Reader composition creates nested function calls - deep nesting may affect stack

## Best Practices

- Use Reader for read-only environment access, not state modification
- Keep environments focused - avoid passing entire application state
- Prefer `asks/1` with specific extractors over `ask/0` with full environment
- Test Reader computations by providing different environments
- Combine Reader with Either/Maybe for error handling and optional values
- Use dependency injection pattern to swap implementations for testing
- Document expected environment structure for Reader computations

## Common Use Cases

### Web Application Configuration

```elixir
# Request processing with configuration
process_request = fn request ->
  Reader.asks(fn config ->
    %{
      max_upload_size: config.upload.max_size,
      allowed_types: config.upload.allowed_types,
      timeout: config.request.timeout
    }
  end)
  |> bind(fn settings -> validate_request(request, settings) end)
end

# Execute with app config
app_config = %{
  upload: %{max_size: 10_000_000, allowed_types: ["jpg", "png"]},
  request: %{timeout: 30_000}
}
result = Reader.run(process_request.(request), app_config)
```

### Database Operations

```elixir
# Database operations with connection
fetch_user = fn user_id ->
  Reader.asks(fn db -> Database.get_user(db, user_id) end)
end

fetch_user_posts = fn user ->
  Reader.asks(fn db -> Database.get_posts_by_user(db, user.id) end)
end

# Compose database operations
get_user_data = fn user_id ->
  fetch_user.(user_id)
  |> bind(fetch_user_posts)
end

# Execute with database connection
db_connection = Database.connect()
user_data = Reader.run(get_user_data.(123), db_connection)
```

### Feature Flag Systems

```elixir
# Feature-dependent behavior
render_component = fn component_type ->
  Reader.asks(fn features ->
    if features.new_ui_enabled do
      render_new_component(component_type)
    else
      render_legacy_component(component_type)
    end
  end)
end

# Usage with feature flags
features = %{new_ui_enabled: true, analytics_enabled: false}
component = Reader.run(render_component.(:navigation), features)
```

## Summary

`Funx.Monad.Reader` provides **deferred computation with read-only environment access**:

- **Deferred execution** - describe computation steps, execute later with environment
- **Environment threading** - automatic context passing without prop drilling
- **Dependency injection** - swap implementations without changing logic
- **Configuration access** - shared settings across computation chains
- **Lazy evaluation** - nothing happens until `Reader.run/2`
- **Read-only access** - environment cannot be modified, only accessed
- **Monadic composition** - chain environment-dependent computations cleanly

**Canon**: Use Reader for dependency injection, configuration access, and avoiding prop drilling. Always `run/2` to execute deferred computations.
