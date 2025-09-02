# Funx Usage Rules (Index)

Usage rules describe how to use Funx protocols and utilities in practice.  
They complement the module docs (which describe *what* the APIs do).  

Each protocol or major module has its own `usage-rules.md`, stored next to the code.  
This index links them together.

---

## Available Rules

- [Funx.Eq Usage Rules](./eq/usage-rules.md)  
  Equality and identity logic across domain types.

- [Funx.Ord Usage Rules](./ord/usage-rules.md)  
  Ordering and comparison logic for domain types.

- [Funx.List Usage Rules](./list/usage-rules.md)  
  Set operations, deduplication, and sorting that respect `Eq` and `Ord`.

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
  eq/
    usage-rules.md      # ← Funx.Eq rules
  ord/
    usage-rules.md      # ← Funx.Ord rules
  list/
    usage-rules.md      # ← Funx.List rules
```
