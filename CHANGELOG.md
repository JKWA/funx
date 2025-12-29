# Changelog

## [0.5.0] - Unreleased

### Added

* `Funx.Optics.Traversal` – A composable optic for accessing multiple foci simultaneously. Supports filtering, combining multiple optics, and working with collections.
* `Funx.Ord.Dsl` – A declarative DSL for building custom ordering comparators with support for multiple projections, ascending/descending order, and automatic identity tiebreakers.
* `Funx.Eq.Dsl` – A declarative DSL for building equality comparators with support for projections, boolean logic (`all`/`any` blocks), and negation (`diff_on`).

### Breaking

* `Funx.List.maybe_head/1` renamed to `Funx.List.head/1` for consistency with `head!/1`. The function still returns `Maybe.t()` for safe head access.

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
