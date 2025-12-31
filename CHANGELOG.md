# Changelog

## [0.6.0] - Unreleased

### Breaking Changes

**Module reorganization** for cleaner separation of protocols and utilities:

#### Eq Module Changes

- **`Funx.Eq` (protocol) → `Funx.Eq.Protocol`**
  - The equality protocol is now `Funx.Eq.Protocol`
  - Protocol implementations must use `defimpl Funx.Eq.Protocol, for: YourType`

- **`Funx.Eq.Utils` → `Funx.Eq`**
  - Utility functions moved from `Funx.Eq.Utils` to `Funx.Eq`
  - DSL merged into `Funx.Eq` (no more separate `Funx.Eq.Dsl`)
  - `use Funx.Eq` imports the `eq` DSL macro
  - `alias Funx.Eq` for utility functions (optional, or use fully qualified)

#### Ord Module Changes

- **`Funx.Ord` (protocol) → `Funx.Ord.Protocol`**
  - The ordering protocol is now `Funx.Ord.Protocol`
  - Protocol implementations must use `defimpl Funx.Ord.Protocol, for: YourType`

- **`Funx.Ord.Utils` → `Funx.Ord`**
  - Utility functions moved from `Funx.Ord.Utils` to `Funx.Ord`
  - DSL merged into `Funx.Ord` (no more separate `Funx.Ord.Dsl`)
  - `use Funx.Ord` imports the `ord` DSL macro
  - `alias Funx.Ord` for utility functions (optional, or use fully qualified)

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

- Functions with `ord \\ Ord` now use `ord \\ Funx.Ord.Protocol`
- DSL parser defaults to `Funx.Ord.Protocol` for comparison checks

### Rationale

This reorganization provides:

- Clear separation: Protocols (`*.Protocol`) vs utilities (`Funx.Eq`, `Funx.Ord`)
- Minimal imports: `use` imports only the DSL macro, not all functions
- Better discoverability: Main modules contain the utilities users interact with
- User control: Users decide whether to alias or use fully qualified names

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

- Core functionality implementation and stabilization
- Comprehensive usage rules and documentation for humans and LLMs
- Real-world testing and feedback incorporation
- API refinement based on practical usage patterns

**Current Status**: Feature-complete beta with comprehensive documentation. Ready for experimentation and feedback, but expect potential API changes before 1.0.

## Feedback Welcome

- 🐛 **Issues**: [Report bugs and suggest improvements](https://github.com/JKWA/funx/issues)
- 📖 **Documentation**: Help us improve usage rules and examples
- 🧪 **Real-world usage**: Share your experience using Funx in projects
- 💬 **Discussion**: Join conversations about functional programming patterns in Elixir

---

*Detailed changelog will begin with version 1.0. Until then, see [GitHub releases](https://github.com/JKWA/funx/releases) for version-specific changes.*
