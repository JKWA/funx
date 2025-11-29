# Used by "mix format"

# Export formatter rules for the Either DSL
# This allows projects that add `import_deps: [:funx]` to automatically
# format DSL functions without extra parentheses
export_locals_without_parens = [
  # DSL entry point
  either: 2,
  # DSL operations
  bind: 1,
  map: 1,
  run: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,examples}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
