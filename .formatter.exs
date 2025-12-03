# Used by "mix format"

# Export formatter rules for the Either DSL
# This allows projects that add `import_deps: [:funx]` to automatically
# format DSL functions without extra parentheses
export_locals_without_parens = [
  either: 2,
  bind: 1,
  map: 1,
  ap: 1,
  validate: 1,
  filter_or_else: 2,
  or_else: 1,
  map_left: 1,
  tap: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,examples}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
