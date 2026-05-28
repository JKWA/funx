# Changelog

## [0.8.7] - Unreleased

### Added

* `Funx.Validator` – New presence and content validators:
  * `NonEmpty` – Validates that a list is not empty
  * `NotBlank` – Validates that a string is not blank (not empty or whitespace-only)

* `Funx.Predicate` – Corresponding predicate modules for presence and content:
  * `NonEmpty` – Checks if a list is not empty (returns `true` for `[1, 2, 3]`, `false` for `[]`)
  * `NotBlank` – Checks if a string is not blank (returns `true` for `"hello"`, `false` for `""` or `"   "`)

These validators complement the existing `Required` validator, providing specific validation for non-empty collections and non-blank strings. They follow the same pattern as existing validators/predicates.

## [0.8.6] - Unreleased

### Added

* `Funx.Validator` – New type validators for basic Elixir types:
  * `String` – Validates that the value is a string (binary)
  * `Float` – Validates that the value is a float
  * `Number` – Validates that the value is a number (integer or float)
  * `Boolean` – Validates that the value is a boolean (true or false)
  * `Atom` – Validates that the value is an atom
  * `List` – Validates that the value is a list
  * `Map` – Validates that the value is a map

* `Funx.Predicate` – Corresponding predicate modules for type checking:
  * `String` – `is_binary/1` check
  * `Float` – `is_float/1` check
  * `Number` – `is_number/1` check
  * `Boolean` – `is_boolean/1` check
  * `Atom` – `is_atom/1` check
  * `List` – `is_list/1` check
  * `Map` – `is_map/1` check

These follow the same pattern as the existing validators/predicates.

## [0.8.5] - Unreleased

### Added

* `Funx.Optics.Prism` – Generalized `key/1` and `path/1` to support any `term()` as a key. This allows for easier navigation of JSON-like data with string keys while maintaining support for atom keys and struct-typed field access.

### Updated

* Validation normalization is now consistent across `Either.validate/3`, the Either DSL `validate` step, and `Funx.Validate`.
  * Supported validator returns are normalized uniformly: `Either`, `:ok`, `{:ok, value}`, and `{:error, error}`
  * `:ok` preserves the original validated value in all validation paths
* Validation docs, usage rules, and Livebooks were aligned with the current validator contract and normalization behavior.

## [0.8.4] - Unreleased

### Fixed

* Eq, Ord, and Predicate DSL parsers now ensure referenced modules are compiled before calling `function_exported?/3`.
  * Fixes behaviour-module detection during DSL compilation for `Funx.Eq`, `Funx.Ord`, and `Funx.Predicate`

## [0.8.3] - Unreleased

### Added

* `Funx.Predicate` – Built-in predicate modules for use in the Predicate DSL:
  * `Eq` / `NotEq` – Equality and inequality checks using `Eq` comparator
  * `In` / `NotIn` – List membership and exclusion checks
  * `LessThan` / `LessThanOrEqual` / `GreaterThan` / `GreaterThanOrEqual` – Comparison predicates using `Ord` comparator
  * `IsTrue` / `IsFalse` – Strict boolean equality checks
  * `MinLength` / `MaxLength` – String length constraints
  * `Pattern` – Regex pattern matching
  * `Integer` / `Positive` / `Negative` – Numeric type and sign checks
  * `Required` – Presence check (not nil, not empty string)
  * `Contains` – List contains element check

* Predicate DSL enhancements:
  * Tuple syntax support in `check` directive: `check :field, {Module, opts}`
  * Bare module syntax for predicates without options: `check :field, Required`
  * Default truthy check when `check` has no predicate: `check :field` (equivalent to `!!value`)

## [0.8.2] - Unreleased

### Added

* `List` group, group_sort, and partition
* Bare fn for `Eq` DSL
* `Eq` `compose_all`, `compose_any`
* `Ord` `compose`

### Deprecated

* Eq `append_all`, `append_any`, `concat_all`, `concat_any` (use `compose_all` and `compose_any`)
* Ord `append`, `concat` (use `compose`)

## [0.8.1] - Unreleased

### Added

* Added mismatch struct logic to eq macro (same as ord)

## [0.8.0] - Unreleased

### Added

* Can now use DSL `Eq` and `Ord` in the Macro `eq_for` and `ord_for`

### Breaking Changes

* Ord DSL no longer adds default protocol tiebreaker. Instead, add it explicitly with `Ord.Protocol`:

```elixir
ord do
  desc :name
  asc Ord.Protocol
end
```

This makes the DSL more composable.

## [0.7.1] - Unreleased

### Added

* Exported .formatter to hex

## [0.7.0] - Unreleased

### Added

* `Funx.Validate` – A declarative DSL for building composable validators with optics-based field projection, applicative error accumulation, and identity preservation. Supports sequential and parallel modes, environment passing, and composable nested validators.
* `Funx.Validator` – Built-in validators for common validation patterns:
  * `Required` – Presence validation (handles `Nothing` from Prism)
  * `Email` – Email format validation
  * `MinLength` / `MaxLength` – String length constraints
  * `Pattern` – Regex pattern matching
  * `Positive` / `Negative` – Numeric sign validation
  * `Integer` – Integer type validation
  * `GreaterThan` / `LessThan` / `GreaterThanOrEq` / `LessThanOrEq` – Numeric comparisons
  * `In` / `NotIn` – Set membership validation
  * `Range` – Numeric range validation
  * `Each` – Collection item validation
  * `Confirmation` – Field matching validation
  * `Not` – Validator negation

### Breaking Changes

* Removed the import Either and import Maybe from the DSLs.
* Changed behavior for Either and Maybe to use Monad behaviours (not `run/3` and `run_maybe/3`)

## [0.6.1] - Unreleased

### Added

* `Funx.Predicate.DSL` – A declarative DSL for building boolean predicates with support for logical operators (`all`/`any`/`negate`), projections via optics or functions (`check`), and reusable validation modules.

## [0.6.0] - Unreleased

### Breaking Changes

**Module reorganization** for cleaner separation of protocols and utilities:

#### Eq Module Changes

* **`Funx.Eq` (protocol) → `Funx.Eq.Protocol`**
  * The equality protocol is now `Funx.Eq.Protocol`
  * Protocol implementations must use `defimpl Funx.Eq.Protocol, for: YourType`

* **`Funx.Eq.Utils` → `Funx.Eq`**
  * Utility functions moved from `Funx.Eq.Utils` to `Funx.Eq`
  * DSL merged into `Funx.Eq` (no more separate `Funx.Eq.Dsl`)
  * `use Funx.Eq` imports the `eq` DSL macro
  * `alias Funx.Eq` for utility functions (optional, or use fully qualified)

#### Ord Module Changes

* **`Funx.Ord` (protocol) → `Funx.Ord.Protocol`**
  * The ordering protocol is now `Funx.Ord.Protocol`
  * Protocol implementations must use `defimpl Funx.Ord.Protocol, for: YourType`

* **`Funx.Ord.Utils` → `Funx.Ord`**
  * Utility functions moved from `Funx.Ord.Utils` to `Funx.Ord`
  * DSL merged into `Funx.Ord` (no more separate `Funx.Ord.Dsl`)
  * `use Funx.Ord` imports the `ord` DSL macro
  * `alias Funx.Ord` for utility functions (optional, or use fully qualified)

#### Migration Guide

**Eq changes:**

```elixir
# Before
alias Funx.Eq.Utils
use Funx.Eq.Dsl
Utils.contramap(&(&1.age))

defimpl Funx.Eq, for: MyStruct do
  def eq?(a, b), do: a.id == b.id
end

# After
use Funx.Eq              # Imports eq DSL macro
alias Funx.Eq            # For utility functions

Eq.contramap(&(&1.age))

defimpl Funx.Eq.Protocol, for: MyStruct do
  def eq?(a, b), do: a.id == b.id
end
```

**Ord changes:**

```elixir
# Before
alias Funx.Ord.Utils
use Funx.Ord.Dsl
Utils.contramap(&(&1.score))

defimpl Funx.Ord, for: MyStruct do
  def lt?(a, b), do: a.score < b.score
end

# After
use Funx.Ord             # Imports ord DSL macro
alias Funx.Ord           # For utility functions

Ord.contramap(&(&1.score))

defimpl Funx.Ord.Protocol, for: MyStruct do
  def lt?(a, b), do: a.score < b.score
end
```

**Default parameter changes:**

* Functions with `ord \\ Ord` now use `ord \\ Funx.Ord.Protocol`
* DSL parser defaults to `Funx.Ord.Protocol` for comparison checks

### Rationale

This reorganization provides:

* Clear separation: Protocols (`*.Protocol`) vs utilities (`Funx.Eq`, `Funx.Ord`)
* Minimal imports: `use` imports only the DSL macro, not all functions
* Better discoverability: Main modules contain the utilities users interact with
* User control: Users decide whether to alias or use fully qualified names

## [0.5.0] - Unreleased

### Added

* `Funx.Optics.Traversal` – A composable optic for accessing multiple foci simultaneously. Supports filtering, combining multiple optics, and working with collections.
* `Funx.Ord.Dsl` – A declarative DSL for building custom ordering comparators with support for multiple projections, ascending/descending order, and automatic identity tiebreakers.
* `Funx.Eq.Dsl` – A declarative DSL for building equality comparators with support for projections, boolean logic (`all`/`any` blocks), and negation (`diff_on`).

### Breaking

* `Funx.List.maybe_head` renamed to `Funx.List.head/1` for consistency with `head!/1`. The function still returns `Maybe.t()` for safe head access.

## [0.4.2] - Unreleased

### Added

* `Funx.Optics.Iso` – A lawful isomorphism optic for reversible, lossless transformations between equivalent representations.
* `Funx.Maybe.Dsl` – A structured DSL for sequencing `Maybe` computations with explicit boundaries, validation, and side effects.

## [0.4.0] - Unreleased

### Added

Introduced **Optics** for composable, lawful data access and transformation:

* `Funx.Optics.Lens` - Total optic for required fields. Raises `KeyError` if focus is missing. Use for fields that should always exist.
* `Funx.Optics.Prism` - Partial optic for optional fields. Returns `Maybe`. Use for fields that may be absent or for selecting struct types.
* `Funx.Monoid.Optics.LensCompose` - Monoid wrapper for sequential lens composition
* `Funx.Monoid.Optics.PrismCompose` - Monoid wrapper for sequential prism composition

## [0.3.0] - Unreleased

### Added

Introduced a Funx.Tap protocol and migrated all monads to use protocol-based tap.

## Changed

tap implementations for Identity, Maybe, Either, Reader, and Effect now delegate through the Funx.Tap protocol.

## Breaking

Existing direct tap/2 implementations have been removed. Code relying on the previous module-specific tap implementations require updates.

## [0.2.3] - Unreleased

### Updated

* Refactored the Either DSL implementation to make it safer and easier to maintain.

## [0.2.2] - Unreleased

### Added

* Add `tap` behavior across Identity, Maybe, Either, Reader, and Effect Monads
* Add `tap` behavior to Either DSL

## [0.2.0] - Unreleased

### Added

* Either DSL for writing declarative error-handling pipelines with support for `bind`, `map`, `ap`, `validate`, and Either functions (`filter_or_else`, `or_else`, `map_left`, `flip`)

## Beta Status (v0.1.x)

⚠️ **Funx is in active development. APIs may change until version 1.0.**

We're currently in beta, focusing on:

* Core functionality implementation and stabilization
* Comprehensive usage rules and documentation for humans and LLMs
* Real-world testing and feedback incorporation
* API refinement based on practical usage patterns

**Current Status**: Feature-complete beta with comprehensive documentation. Ready for experimentation and feedback, but expect potential API changes before 1.0.

## Feedback Welcome

* 🐛 **Issues**: [Report bugs and suggest improvements](https://github.com/JKWA/funx/issues)
* 📖 **Documentation**: Help us improve usage rules and examples
* 🧪 **Real-world usage**: Share your experience using Funx in projects
* 💬 **Discussion**: Join conversations about functional programming patterns in Elixir

---

*Detailed changelog will begin with version 1.0. Until then, see [GitHub releases](https://github.com/JKWA/funx/releases) for version-specific changes.*
