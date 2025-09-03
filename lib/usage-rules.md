# Funx Usage Rules (Index)

Usage rules describe how to use Funx protocols and utilities in practice.  
They complement the module docs (which describe *what* the APIs do).  

Each protocol or major module has its own `usage-rules.md`, stored next to the code.  
This index links them together.

---

## Available Rules

- [Funx.Utils Usage Rules](./utils/usage-rules.md)  
  Currying, flipping, and function transformation for point-free and pipeline-based composition.

- [Funx.Eq Usage Rules](./eq/usage-rules.md)  
  Equality and identity logic across domain types.

- [Funx.Ord Usage Rules](./ord/usage-rules.md)  
  Ordering and comparison logic for domain types.

- [Funx.List Usage Rules](./list/usage-rules.md)  
  Set operations, deduplication, and sorting that respect `Eq` and `Ord`.

- [Funx.Monoid Usage Rules](./monoid/usage-rules.md)  
  Identities and associative combination, powering folds and composition.

- [Funx.Predicate Usage Rules](./predicate/usage-rules.md)  
  Logical composition of predicates using short-circuiting, reusable combinators.
  
- [Funx.Monad Usage Rules](./monad/usage-rules.md)
  Declarative control flow through `map`, `bind`, and `ap`—composing context-aware steps without manual branching.

---

## Conventions

- Collocation: rules live beside the code they describe.  
- Scope: focus on *usage guidance* and best practices, not API reference.  
- LLM-friendly: small sections, explicit examples, stable links.

---

## Project Layout (rules only)

```text
lib/
  usage-rules.md        # ← index (this file)
  utils/
    usage-rules.md      # ← Funx.Utils rules
  eq/
    usage-rules.md      # ← Funx.Eq rules
  ord/
    usage-rules.md      # ← Funx.Ord rules
  list/
    usage-rules.md      # ← Funx.List rules
  monoid/
    usage-rules.md      # ← Funx.Monoid rules
  predicate/
    usage-rules.md      # ← Funx.Predicate rules
  monad/
    usage-rules.md      # ← Funx.Monad rules
```
