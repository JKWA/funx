# Livebook Creation Usage Rules

This document provides guidance for recreating and validating the livebook documentation extracted from the Funx codebase.

## Purpose

These livebooks contain exact transcriptions of embedded documentation (`@moduledoc` and `@doc` strings) from the Funx library's `.ex` source files, converted to interactive livebook format for enhanced learning and exploration.

## Creation Process

### 1. File Discovery Pattern

Find all `.ex` source files to process:

```bash
# Find main modules
find lib -name "*.ex" -type f

# Pattern used:
lib/**/*.ex
```

### 2. Directory Structure Mapping

The livebook structure mirrors the source code organization:

```
lib/eq.ex → livebooks/eq.livemd
lib/eq/utils.ex → livebooks/eq/utils.livemd
lib/monad/maybe.ex → livebooks/monad/maybe.livemd
lib/monad/maybe/just.ex → livebooks/monad/maybe/just.livemd
```

**Note**: The `lib/` level may be flattened in the livebooks directory.

### 3. Documentation Extraction Rules

#### CRITICAL: Exact Transcription Only

- **Extract**: Only `@moduledoc` and `@doc` strings from source files
- **Preserve**: Every word, punctuation mark, formatting exactly as written
- **Exclude**: Implementation code, specs, types, imports, aliases
- **No changes**: No paraphrasing, reorganization, additions, or modifications

#### Content to Extract

From each `.ex` file:
1. `@moduledoc """..."""` content (module-level documentation)
2. All `@doc """..."""` content (function-level documentation)
3. Examples within doc strings (preserve formatting)
4. Section headers and structure within doc strings

#### Content to Ignore

- `@spec` type specifications
- Function implementations
- `import`, `alias`, `use` statements
- Private functions (those starting with `@doc false`)
- Comments (`# ...`)

### 4. Livebook Structure Template

Each livebook should follow this exact format:

```markdown
# [Module Name]

[Module documentation - exactly as written in @moduledoc]

## [function_name/arity]

[Function documentation - exactly as written in @doc]

### Examples

[Examples exactly as written in the @doc]
```

### 5. Processing Approach

#### Manual Method (Small batches)
1. Read source file
2. Extract `@moduledoc` and `@doc` strings
3. Create livebook with template structure
4. Transcribe exactly without changes

#### Automated Method (Large batches)
Use the Task tool with general-purpose agent:
```
Process files by extracting all @moduledoc and @doc strings exactly as they appear and create livebook files with exact transcription.
```

## Validation Rules

### Content Validation
- [ ] Every `@moduledoc` from source appears in livebook
- [ ] Every `@doc` from source appears in livebook  
- [ ] No content added that wasn't in original docs
- [ ] All examples preserved with exact formatting
- [ ] Code blocks maintain proper syntax highlighting

### Structure Validation
- [ ] Directory structure mirrors source organization
- [ ] File naming convention: `.ex` → `.livemd`
- [ ] Livebook sections follow template structure
- [ ] No missing modules or functions

### Quality Validation
- [ ] No spelling changes or "corrections"
- [ ] No grammar modifications
- [ ] No reorganization of content
- [ ] All technical terms preserved exactly
- [ ] Examples remain runnable and accurate

## File Coverage

### Protocols and Main Modules
- [x] `eq.ex`, `eq/utils.ex` (Equality protocol)
- [x] `ord.ex`, `ord/utils.ex` (Ordering protocol) 
- [x] `predicate.ex` (Predicate combinators)
- [x] `foldable.ex` (Folding protocol)
- [x] `filterable.ex` (Filtering protocol)

### Monoids (13 files)
- [x] `monoid.ex` (main protocol)
- [x] All `monoid/*.ex` implementations

### Monads (15 files)
- [x] `monad.ex` (main protocol)
- [x] All `monad/*.ex` implementations
- [x] All monad variant files (`maybe/just.ex`, `either/left.ex`, etc.)

### Utilities and Support
- [x] `utils.ex`, `list.ex`, `math.ex`
- [x] `macros.ex`, `config.ex`
- [x] `errors/*.ex` modules
- [x] `appendable.ex`, `summarizable.ex`, `range.ex`

## Common Mistakes to Avoid

### ❌ Don't Do
- Modify or "improve" the original documentation text
- Add explanatory text or introductions
- Reorganize sections or change structure
- Fix spelling or grammar in the original
- Combine multiple `@doc` strings
- Skip functions that seem "unimportant"

### ✅ Do
- Copy text character-for-character
- Preserve all formatting and indentation
- Include every `@moduledoc` and `@doc`
- Maintain original section headers
- Keep examples exactly as written
- Test that examples are still valid

## Regeneration Command Pattern

For future recreation, use this systematic approach:

1. **Discover**: `find lib -name "*.ex" -type f`
2. **Batch process**: Group related modules (eq, ord, monad, monoid)
3. **Extract**: Use Task tool for systematic extraction
4. **Validate**: Check completeness against source files

## Quality Assurance

Before completing:
1. Compare livebook count to `.ex` file count
2. Spot-check random files for exact transcription
3. Verify all directory structures created
4. Confirm no implementation code leaked in
5. Test example code blocks are properly formatted

---

**Principle**: These livebooks are documentation mirrors, not documentation rewrites. Preserve the author's exact words and structure.

## Livebook Formatting Rules

### Interactive Code Examples

After initial transcription, livebook examples must be optimized for interactive execution:

#### 1. Remove Result Comments
- **Remove all result comments** like `# true`, `# false`, `# :ok`, `# [%{name: "Alice"}]`
- Livebook shows actual execution results, making these comments redundant and potentially misleading
- Clean code examples let users see real output

#### 2. Split Grouped Examples
- **Separate grouped examples into individual code blocks**
- Livebook only shows the result of the last expression in each block
- Each example should run independently and show its own result
- **Before**: One block with multiple `iex>` examples
- **After**: Multiple blocks, each with one example

#### 3. Use Imported Function Names
- **Leverage import statements** to use short function names
- If `import Funx.Eq.Utils` is present, use `eq?()` instead of `Funx.Eq.Utils.eq?()`
- If `import Funx.Monad.Maybe` is present, use `just()` instead of `Funx.Monad.Maybe.just()`
- Makes examples cleaner and demonstrates import benefits

### Transformation Examples

#### Before (Original):
```markdown
### Examples

```elixir
Funx.Eq.Utils.eq?(42, 42)
# true

Funx.Eq.Utils.eq?("foo", "bar")
# false
```
```

#### After (Livebook-optimized):
```markdown
### Examples

```elixir
eq?(42, 42)
```

```elixir
eq?("foo", "bar")
```
```

### Batch Processing Approach

For applying these transformations efficiently:

1. **Use Task tool with general-purpose agent** for batch processing
2. **Pattern-based replacement**:
   - Find and remove all result comments (`# .*`)
   - Split multi-example blocks (look for multiple function calls)
   - Replace fully qualified names based on existing import statements
3. **Process by module type** (monads, monoids, protocols) for consistency
4. **Validation**: Spot-check files after each batch for accuracy

### Manual Processing for Special Cases

Some files may require manual processing:
- Files with `iex>` examples need conversion to ````elixir` blocks
- Complex multi-step examples may need careful splitting
- Files with mixed documentation styles require individual attention

### Common Import Patterns

Map fully qualified names to short names based on imports:

- `import Funx.Eq.Utils` → `Funx.Eq.Utils.eq?` becomes `eq?`
- `import Funx.Monad.Maybe` → `Funx.Monad.Maybe.just` becomes `just`
- `import Funx.Predicate` → `Funx.Predicate.p_and` becomes `p_and`
- `import Funx.Ord.Utils` → `Funx.Ord.Utils.max` becomes `max`

## Key Principles Learned

### Interactive vs Static Documentation
- **One result per block**: Livebook only shows the last expression result in each code block
- **No result comments**: Let users see actual execution instead of `# true`, `# false` comments  
- **Independent execution**: Each code block should be runnable on its own

### Leverage Language Features
- **Use imports effectively**: `contramap()` is cleaner than `Funx.Eq.Utils.contramap()`
- **Demonstrate setup benefits**: Show why the import/alias blocks matter
- **Clean, readable examples**: Focus on the functionality, not boilerplate

### Systematic Processing Works
- **Batch processing**: Use agents for consistent transformations across many files
- **Pattern-based approach**: Apply the same rules systematically
- **Document the process**: So it can be repeated reliably

### Content Fidelity + Format Adaptation
- **Preserve exact documentation**: Never change the author's words or structure
- **Adapt for the medium**: But optimize presentation for interactive use
- **Faithful content, smart formatting**: Best of both worlds

### Special Case Handling
- **iex> examples**: Convert to ````elixir` blocks for proper syntax highlighting
- **Multi-step examples**: May need manual attention for optimal splitting
- **Mixed styles**: Some files require individual review rather than batch processing

**Principle**: These livebooks are documentation mirrors, not documentation rewrites. Preserve the author's exact words and structure while optimizing for interactive execution.