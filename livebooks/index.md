# Funx Library - Interactive Documentation

Welcome to the Funx library livebook documentation! This collection provides interactive exploration of functional programming concepts in Elixir.

## Core Protocols

### Equality & Ordering
- [Eq Protocol](eq/eq.livemd) - Domain-specific equality
- [Eq Utils](eq/utils.livemd) - Equality utilities and combinators
- [Ord Protocol](ord/ord.livemd) - Context-aware ordering
- [Ord Utils](ord/utils.livemd) - Ordering utilities and combinators

### Structure Operations
- [Foldable Protocol](foldable/foldable.livemd) - Structure folding
- [Filterable Protocol](filterable/filterable.livemd) - Conditional value retention

## Type Classes

### Monads
- [Monad Protocol](monad/monad.livemd) - Monadic operations (map, bind, ap)

#### Maybe Monad
- [Maybe](monad/maybe/maybe.livemd) - Optional computation
- [Just](monad/maybe/just.livemd) - Maybe success case
- [Nothing](monad/maybe/nothing.livemd) - Maybe failure case

#### Either Monad  
- [Either](monad/either/either.livemd) - Error handling and validation
- [Left](monad/either/left.livemd) - Either failure case
- [Right](monad/either/right.livemd) - Either success case

#### Effect Monad
- [Effect](monad/effect/effect.livemd) - Railway-oriented programming
- [Effect Context](monad/effect/context.livemd) - Effect execution context
- [Effect Left](monad/effect/left.livemd) - Effect failure case
- [Effect Right](monad/effect/right.livemd) - Effect success case

#### Other Monads
- [Identity](monad/identity/identity.livemd) - Simple wrapper monad
- [Reader](monad/reader/reader.livemd) - Environment access
- [Writer](monad/writer/writer.livemd) - Computation with logging
- [Writer Result](monad/writer/result.livemd) - Writer result wrapper

### Monoids
- [Monoid Protocol](monoid/monoid.livemd) - Identity and associative combination
- [Monoid Utils](monoid/utils.livemd) - Monoid utilities

#### Numeric Monoids
- [Sum](monoid/sum.livemd) - Addition monoid
- [Product](monoid/product.livemd) - Multiplication monoid
- [Min](monoid/min.livemd) - Minimum value monoid
- [Max](monoid/max.livemd) - Maximum value monoid

#### Collection Monoids
- [List Concat](monoid/list_concat.livemd) - List concatenation
- [String Concat](monoid/string_concat.livemd) - String concatenation

#### Logic Monoids
- [Eq All](monoid/eq_all.livemd) - All-equality monoid
- [Eq Any](monoid/eq_any.livemd) - Any-equality monoid
- [Pred All](monoid/pred_all.livemd) - All-predicate monoid
- [Pred Any](monoid/pred_any.livemd) - Any-predicate monoid
- [Ord](monoid/ord.livemd) - Ordering monoid

## Utilities & Combinators

### Function Utilities
- [Utils](utilities/utils.livemd) - Currying and function transformation
- [Predicate](predicate/predicate.livemd) - Logical composition

### Data Structures
- [List](list/list.livemd) - Set operations and deduplication
- [Range](range/range.livemd) - Range utilities
- [Math](math/math.livemd) - Mathematical operations

### Protocols & Extensions
- [Appendable](appendable/appendable.livemd) - Appendable protocol
- [Summarizable](summarizable/summarizable.livemd) - Summarizable protocol

## Infrastructure

### Error Handling
- [Effect Error](errors/effect_error.livemd) - Effect error types
- [Validation Error](errors/validation_error.livemd) - Validation error types

### Development
- [Config](config/config.livemd) - Configuration utilities
- [Macros](macros/macros.livemd) - Macro utilities

## Getting Started

1. **New to functional programming?** Start with [Eq Protocol](eq/eq.livemd) and [Utils](utilities/utils.livemd)
2. **Want to handle errors elegantly?** Explore [Maybe](monad/maybe/maybe.livemd) and [Either](monad/either/either.livemd)
3. **Need to combine values?** Check out [Monoid Protocol](monoid/monoid.livemd) and its implementations
4. **Working with collections?** See [Foldable](foldable/foldable.livemd) and [List](list/list.livemd)

Each livebook is interactive - you can run the examples and experiment with the code directly!