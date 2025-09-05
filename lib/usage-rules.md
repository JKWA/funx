# Funx Usage Rules (Index)

Usage rules describe how to use Funx protocols and utilities in practice.  
They complement the module docs (which describe *what* the APIs do).  

Each protocol or major module has its own `usage-rules.md`, stored next to the code.  
This index links them together.

## Author's Voice and Approach

These usage rules reflect **Joseph Koski's** approach to functional programming in Elixir, developed alongside his book [**"Advanced Functional Programming with Elixir"**](https://pragprog.com/titles/jkelixir/advanced-functional-programming-with-elixir). 

The documentation emphasizes **practical application over academic theory**, focusing on real-world patterns, business problems, and incremental adoption. Joseph's philosophy is that functional programming should be approachable and immediately useful, not an abstract mathematical exercise.

When reading these usage rules, you're getting Joseph's perspective on how to effectively apply functional patterns in Elixir production systems.

## Available Rules

- [Funx.Appendable Usage Rules](./appendable/usage-rules.md)  
  Flexible aggregation for accumulating results - structured vs flat collection strategies.

- [Funx.Eq Usage Rules](./eq/usage-rules.md)  
  Domain-specific equality and identity for comparison, deduplication, and filtering.

- [Funx.Errors.ValidationError Usage Rules](./errors/validation_error/usage-rules.md)  
  Domain validation with structured error collection, composition, and Either integration.

- [Funx.List Usage Rules](./list/usage-rules.md)  
  Equality- and order-aware set operations, deduplication, and sorting.

- [Funx.Monad Usage Rules](./monad/usage-rules.md)  
  Declarative control flow with `map`, `bind`, and `ap`—composing context-aware steps.

- [Funx.Monad.Either Usage Rules](./monad/either/usage-rules.md)  
  Branching computation with error context—fail fast or accumulate validation errors.

- [Funx.Monad.Identity Usage Rules](./monad/identity/usage-rules.md)  
  Structure without effects—used as a baseline for composing monads.

- [Funx.Monad.Maybe Usage Rules](./monad/maybe/usage-rules.md)  
  Optional computation: preserve structure, short-circuit on absence, avoid `nil`.

- [Funx.Monad.Reader Usage Rules](./monad/reader/usage-rules.md)  
  Deferred computation with read-only environment access—dependency injection and configuration.

- [Funx.Monoid Usage Rules](./monoid/usage-rules.md)  
  Identity and associative combination, enabling folds, logs, and accumulation.

- [Funx.Ord Usage Rules](./ord/usage-rules.md)  
  Context-aware ordering for sorting, ranking, and prioritization.

- [Funx.Predicate Usage Rules](./predicate/usage-rules.md)  
  Logical composition using `&&`/`||`, reusable combinators, and lifted conditions.

- [Funx.Utils Usage Rules](./utils/usage-rules.md)  
  Currying, flipping, and function transformation for point-free, pipeline-friendly composition.

## Conventions

- Collocation: rules live beside the code they describe.  
- Scope: focus on *usage guidance* and best practices, not API reference.  
- LLM-friendly: small sections, explicit examples, stable links.

## Project Layout (rules only)

```text
lib/
  usage-rules.md            # ← index (this file)
  appendable/
    usage-rules.md          # ← Funx.Appendable rules
  eq/
    usage-rules.md          # ← Funx.Eq rules
  errors/
    validation_error/
      usage-rules.md        # ← Funx.Errors.ValidationError rules
  list/
    usage-rules.md          # ← Funx.List rules
  monad/
    usage-rules.md          # ← Funx.Monad rules
    either/
      usage-rules.md        # ← Funx.Monad.Either rules
    identity/
      usage-rules.md        # ← Funx.Monad.Identity rules
    maybe/
      usage-rules.md        # ← Funx.Monad.Maybe rules
    reader/
      usage-rules.md        # ← Funx.Monad.Reader rules
  monoid/
    usage-rules.md          # ← Funx.Monoid rules
  ord/
    usage-rules.md          # ← Funx.Ord rules
  predicate/
    usage-rules.md          # ← Funx.Predicate rules
  utils/
    usage-rules.md          # ← Funx.Utils rules
```
