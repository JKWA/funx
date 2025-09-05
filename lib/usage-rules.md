# Funx Usage Rules (Index)

Usage rules describe how to use Funx protocols and utilities in practice.  
They complement the module docs (which describe *what* the APIs do).  

Each protocol or major module has its own `usage-rules.md`, stored next to the code.  
This index links them together.

## Available Rules

- [Funx.Utils Usage Rules](./utils/usage-rules.md)  
  Currying, flipping, and function transformation for point-free, pipeline-friendly composition.

- [Funx.Eq Usage Rules](./eq/usage-rules.md)  
  Domain-specific equality and identity for comparison, deduplication, and filtering.

- [Funx.Ord Usage Rules](./ord/usage-rules.md)  
  Context-aware ordering for sorting, ranking, and prioritization.

- [Funx.List Usage Rules](./list/usage-rules.md)  
  Equality- and order-aware set operations, deduplication, and sorting.

- [Funx.Monoid Usage Rules](./monoid/usage-rules.md)  
  Identity and associative combination, enabling folds, logs, and accumulation.

- [Funx.Predicate Usage Rules](./predicate/usage-rules.md)  
  Logical composition using `&&`/`||`, reusable combinators, and lifted conditions.

- [Funx.Monad Usage Rules](./monad/usage-rules.md)  
  Declarative control flow with `map`, `bind`, and `ap`—composing context-aware steps.

- [Funx.Monad.Identity Usage Rules](./monad/identity/usage-rules.md)  
  Structure without effects—used as a baseline for composing monads.

- [Funx.Monad.Maybe Usage Rules](./monad/maybe/usage-rules.md)  
  Optional computation: preserve structure, short-circuit on absence, avoid `nil`.

- [Funx.Monad.Either Usage Rules](./monad/either/usage-rules.md)  
  Branching computation with error context—fail fast or accumulate validation errors.

- [Funx.Errors.ValidationError Usage Rules](./errors/validation_error/usage-rules.md)  
  Domain validation with structured error collection, composition, and Either integration.

- [Funx.Appendable Usage Rules](./appendable/usage-rules.md)  
  Flexible aggregation for accumulating results - structured vs flat collection strategies.

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
  monoid/
    usage-rules.md          # ← Funx.Monoid rules
  ord/
    usage-rules.md          # ← Funx.Ord rules
  predicate/
    usage-rules.md          # ← Funx.Predicate rules
  utils/
    usage-rules.md          # ← Funx.Utils rules
```
