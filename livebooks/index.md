# Funx Library - Interactive Documentation

This collection provides interactive exploration of functional programming concepts in Elixir using the Funx library.

These files are on GitHub, and reflect the latest development version.

For the stable API reference, use the project's [hex documentation](https://hexdocs.pm/funx/readme.html).  

## Core Protocols

### Equality & Ordering

- ▶️ [Eq Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Feq%2Feq.livemd) - Domain-specific equality
- ▶️ [Eq Utils](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Feq%2Futils.livemd) - Equality utilities and combinators
- ▶️ [Ord Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ford%2Ford.livemd) - Context-aware ordering
- ▶️ [Ord Utils](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ford%2Futils.livemd) - Ordering utilities and combinators

### Structure Operations

- ▶️ [Foldable Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ffoldable%2Ffoldable.livemd) - Structure folding
- ▶️ [Filterable Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ffilterable%2Ffilterable.livemd) - Conditional value retention

## Type Classes

### Monads

- ▶️ [Monad Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fmonad.livemd) - Monadic operations (map, bind, ap)

#### Maybe Monad

- ▶️ [Maybe](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fmaybe%2Fmaybe.livemd) - Optional computation
- ▶️ [Just](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fmaybe%2Fjust.livemd) - Maybe success case
- ▶️ [Nothing](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fmaybe%2Fnothing.livemd) - Maybe failure case

#### Either Monad  

- ▶️ [Either](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feither%2Feither.livemd) - Error handling and validation
- ▶️ [Left](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feither%2Fleft.livemd) - Either failure case
- ▶️ [Right](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feither%2Fright.livemd) - Either success case

#### Effect Monad

- ▶️ [Effect](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feffect%2Feffect.livemd) - Railway-oriented programming
- ▶️ [Effect Context](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feffect%2Fcontext.livemd) - Effect execution context
- ▶️ [Effect Left](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feffect%2Fleft.livemd) - Effect failure case
- ▶️ [Effect Right](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feffect%2Fright.livemd) - Effect success case

#### Other Monads

- ▶️ [Identity](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fidentity%2Fidentity.livemd) - Simple wrapper monad
- ▶️ [Reader](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Freader%2Freader.livemd) - Environment access
- ▶️ [Writer](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fwriter%2Fwriter.livemd) - Computation with logging
- ▶️ [Writer Result](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fwriter%2Fresult.livemd) - Writer result wrapper

### Monoids

- ▶️ [Monoid Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fmonoid.livemd) - Identity and associative combination
- ▶️ [Monoid Utils](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Futils.livemd) - Monoid utilities

#### Numeric Monoids

- ▶️ [Sum](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fsum.livemd) - Addition monoid
- ▶️ [Product](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fproduct.livemd) - Multiplication monoid
- ▶️ [Min](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fmin.livemd) - Minimum value monoid
- ▶️ [Max](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fmax.livemd) - Maximum value monoid

#### Collection Monoids

- ▶️ [List Concat](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Flist_concat.livemd) - List concatenation
- ▶️ [String Concat](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fstring_concat.livemd) - String concatenation

#### Logic Monoids

- ▶️ [Eq All](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Feq_all.livemd) - All-equality monoid
- ▶️ [Eq Any](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Feq_any.livemd) - Any-equality monoid
- ▶️ [Pred All](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fpred_all.livemd) - All-predicate monoid
- ▶️ [Pred Any](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fpred_any.livemd) - Any-predicate monoid
- ▶️ [Ord](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Ford.livemd) - Ordering monoid

## Utilities & Combinators

### Function Utilities

- ▶️ [Utils](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Futilities%2Futils.livemd) - Currying and function transformation
- ▶️ [Predicate](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fpredicate%2Fpredicate.livemd) - Logical composition

### Data Structures

- ▶️ [List](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Flist%2Flist.livemd) - Set operations and deduplication
- ▶️ [Range](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Frange%2Frange.livemd) - Range utilities
- ▶️ [Math](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmath%2Fmath.livemd) - Mathematical operations

### Protocols & Extensions

- ▶️ [Appendable](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fappendable%2Fappendable.livemd) - Appendable protocol
- ▶️ [Summarizable](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fsummarizable%2Fsummarizable.livemd) - Summarizable protocol

## Infrastructure

### Error Handling

- ▶️ [Effect Error](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ferrors%2Feffect_error.livemd) - Effect error types
- ▶️ [Validation Error](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ferrors%2Fvalidation_error.livemd) - Validation error types

### Development

- ▶️ [Config](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fconfig%2Fconfig.livemd) - Configuration utilities
- ▶️ [Macros](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmacros%2Fmacros.livemd) - Macro utilities

## Getting Started

1. **New to functional programming?** Start with ▶️ [Eq Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Feq%2Feq.livemd) and ▶️ [Utils](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Futilities%2Futils.livemd)
2. **Want to handle errors elegantly?** Explore ▶️ [Maybe](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fmaybe%2Fmaybe.livemd) and ▶️ [Either](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Feither%2Feither.livemd)
3. **Need to combine values?** Check out ▶️ [Monoid Protocol](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fmonoid.livemd) and its implementations
4. **Working with collections?** See ▶️ [Foldable](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ffoldable%2Ffoldable.livemd) and ▶️ [List](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Flist%2Flist.livemd)
