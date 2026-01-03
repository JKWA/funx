# Used by "mix format"

# Export formatter rules for DSLs
# This allows projects that add `import_deps: [:funx]` to automatically
# format DSL functions without extra parentheses
export_locals_without_parens = [
  # Either DSL
  either: 2,
  bind: 1,
  map: 1,
  ap: 1,
  validate: 1,
  filter_or_else: 2,
  or_else: 1,
  map_left: 1,
  tap: 1,
  # Maybe DSL
  maybe: 2,
  filter: 1,
  filter_map: 2,
  guard: 1,
  # Ord DSL
  asc: 1,
  asc: 2,
  desc: 1,
  desc: 2,
  # Eq DSL
  on: 1,
  on: 2,
  not_on: 1,
  not_on: 2,
  any: 1,
  all: 1,
  # Predicate DSL
  pred: 1,
  check: 2,
  negate: 1,
  negate_all: 1,
  negate_any: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,examples}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
