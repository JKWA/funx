# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Funx is a functional programming library for Elixir that provides protocols and combinators for core functional programming abstractions. It implements monads, monoids, and other functional patterns while preserving Elixir's dynamic nature.

## Development Commands

### Essential Commands
- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix test` - Run tests (100% coverage required)
- `mix test --cover` - Run tests with coverage report
- `mix docs` - Generate documentation

### Makefile Commands
- `make start` - Clean, compile, and start IEx session
- `make lint` - Run Dialyzer static analysis and Credo linting
- `make pre_push` - Run Credo and coverage tests (use before commits)

### Testing
- Tests require 100% code coverage
- Run individual test files: `mix test test/path/to/test_file.exs`
- Coverage reports generated in `cover/` directory
- Property-based testing patterns used for protocol implementations

## Code Architecture

### Core Design Pattern
The library uses Elixir's protocol system to implement functional programming abstractions:

**Protocols** define behavior contracts:
- `Funx.Eq` - Domain-specific equality
- `Funx.Ord` - Context-aware ordering  
- `Funx.Monad` - Monadic operations (map, bind, ap)
- `Funx.Foldable` - Structure folding
- `Funx.Filterable` - Conditional value retention

**Implementations** are organized by category:
- `lib/eq/` - Equality implementations
- `lib/ord/` - Ordering implementations
- `lib/monad/` - Monad implementations (Identity, Maybe, Either, Effect, Writer)
- `lib/monoid/` - Monoid implementations
- `lib/predicate/` - Predicate combinators

### Key Architectural Principles
1. **Protocol-based polymorphism** - Runtime dispatch with static documentation
2. **Functional composition** - Pipeline-friendly APIs with currying support
3. **Explicit error handling** - Either/Effect monads for railway-oriented programming
4. **Type safety through protocols** - Runtime type checking without static typing

### Monad Implementation Pattern
Each monad follows a consistent structure:
```elixir
defmodule Funx.Monad.SomeName do
  # Constructor functions (e.g., new/1, just/1, left/1, right/1)
  # Pattern matching functions (e.g., is_just?/1, is_left?/1)
  # Protocol implementations for Monad, Eq, Ord, etc.
  # Utility functions specific to the monad
end
```

## Documentation System

### Usage Rules (LLM-Friendly Guidance)
**IMPORTANT: Always consult the usage rules before working with Funx protocols and utilities.**

The project includes comprehensive usage rules specifically designed for AI assistants:
- **Index**: `lib/usage-rules.md` - Central navigation for all usage rules
- **Co-located rules**: Each protocol/module has `usage-rules.md` files next to the code
- **Focus**: Practical guidance and best practices, not API reference
- **LLM-optimized**: Small sections, explicit examples, stable links

**Available Usage Rules:**
- `lib/utils/usage-rules.md` - Currying and function transformation
- `lib/eq/usage-rules.md` - Domain-specific equality patterns
- `lib/ord/usage-rules.md` - Context-aware ordering
- `lib/list/usage-rules.md` - Set operations and deduplication
- `lib/monoid/usage-rules.md` - Identity and associative combination
- `lib/predicate/usage-rules.md` - Logical composition
- `lib/monad/usage-rules.md` - General monad usage patterns
- `lib/monad/identity/usage-rules.md` - Identity monad guidance
- `lib/monad/maybe/usage-rules.md` - Optional computation patterns
- `lib/monad/either/usage-rules.md` - Error handling and validation

**Usage Rule Conventions:**
- Rules live beside the code they describe (collocation)
- Focus on usage guidance and best practices
- Designed for AI assistant consumption

### API Documentation Generation
- ExDoc generates comprehensive API documentation
- Doctests are embedded in modules and tested automatically
- Usage examples should be included for all public functions

## Development Workflow

### Code Quality Requirements
- **100% test coverage** (enforced by coveralls.json)
- **Dialyzer static analysis** must pass without warnings
- **Credo linting** with strict rules must pass
- All tests must pass before commits

### Adding New Functionality
1. Identify the appropriate protocol or create a new one
2. Write tests first (TDD approach)
3. Implement the functionality following existing patterns
4. Add protocol implementations as needed
5. Update or create usage rules documentation
6. Ensure 100% test coverage
7. Run `make pre_push` to verify all checks pass

### When Adding New Monads
1. Create directory under `lib/monad/`
2. Implement core constructor and pattern matching functions
3. Implement required protocols (Monad, Eq, Ord minimally)
4. Add comprehensive tests with property-based testing
5. Create usage rules documentation
6. Update `lib/usage-rules.md` index

### Protocol Extensions
When adding protocol implementations for existing types:
1. Add implementation in appropriate category directory
2. Follow existing naming patterns
3. Include comprehensive tests
4. Document any special behavior or constraints

## Testing Patterns

### Protocol Testing
Use property-based testing patterns for protocol laws:
- Monad laws (left identity, right identity, associativity)
- Eq laws (reflexivity, symmetry, transitivity)
- Ord laws (totality, antisymmetry, transitivity)

### Test Organization
- Test files mirror source structure (`test/monad/maybe/` for `lib/monad/maybe/`)
- Use `test/support/` for shared test utilities
- Group related tests in describe blocks
- Include both positive and negative test cases

## Version and Compatibility

- **Elixir**: 1.16+ or 1.17+
- **Erlang/OTP**: 26.2+ or 27.1+
- **Beta Status**: API may change before 1.0 release
- Use `.tool-versions` for consistent development environment