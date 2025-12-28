defmodule Funx.Ord.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Ord DSL
  #
  # ## Error Message Contract
  #
  # These messages are part of the public API. Changes should be:
  # 1. Documented in CHANGELOG
  # 2. Reflected in tests
  # 3. Considered breaking changes if semantics change
  #
  # Each error has:
  # - Clear category (syntax, type, option misuse)
  # - Actionable guidance (what to do instead)
  # - Examples when helpful

  @doc """
  Error: DSL syntax must be `asc projection` or `desc projection`.
  """
  def invalid_dsl_syntax(got) do
    """
    Invalid Ord DSL syntax.

    Expected: `asc projection` or `desc projection`
    Got: #{inspect(got)}

    Valid examples:
      asc :name
      desc :age
      asc Lens.key(:score)
    """
  end

  @doc """
  Error: Captured function with `or_else:` option.
  """
  def or_else_with_captured_function do
    """
    The `or_else:` option cannot be used with captured functions.

    Use one of these alternatives:
      1. Create a 0-arity helper that returns a Prism:
         def score_prism, do: Prism.key(:score)
         asc score_prism(), or_else: 0

      2. Use inline Prism syntax:
         asc Prism.key(:score), or_else: 0

    Reason: Captured functions like &fun/1 don't expose their projection type
    at compile time, making or_else semantics ambiguous.
    """
  end

  @doc """
  Error: Anonymous function with `or_else:` option.
  """
  def or_else_with_anonymous_function do
    """
    The `or_else:` option cannot be used with anonymous functions.

    Use one of these alternatives:
      1. Create a 0-arity helper that returns a Prism:
         def score_prism, do: Prism.key(:score)
         asc score_prism(), or_else: 0

      2. Use inline Prism syntax:
         asc Prism.key(:score), or_else: 0

    Reason: Anonymous functions like `fn x -> x.field end` don't expose their
    projection type at compile time, making or_else semantics ambiguous.
    """
  end

  @doc """
  Error: Lens with `or_else:` option.
  """
  def or_else_with_lens do
    """
    The `or_else:` option is only valid with atoms or Prism projections, not with Lens.

    Reason: Lens guarantees focus on an existing value (or raises an error).
    Adding an or_else would violate this contract.

    If you need optional field handling, use a Prism instead:
      asc Prism.key(:name), or_else: "Unknown"

    Or use an atom with or_else (automatically becomes a Prism):
      asc :name, or_else: "Unknown"
    """
  end

  @doc """
  Error: Behaviour module with `or_else:` option.
  """
  def or_else_with_behaviour do
    """
    The `or_else:` option is only valid with atoms or Prism projections, not with Behaviour modules.

    Reason: Behaviour modules define custom projection logic that may not
    return Maybe values compatible with or_else handling.

    If you need or_else handling, implement it inside your Behaviour:
      defmodule MyProjection do
        @behaviour Funx.Ord.Dsl.Behaviour

        def project(value, opts) do
          value.field || Keyword.get(opts, :or_else, 0)
        end
      end
    """
  end

  @doc """
  Error: Ord variable with `or_else:` option.
  """
  def or_else_with_ord_variable do
    """
    The `or_else:` option cannot be used with ord variables.

    Reason: Ord variables are complete ordering functions that already define
    their own comparison logic. The or_else option only applies to field
    projections that might return nil values.

    If you need to customize the ord variable's behavior, modify it before
    using it in the DSL:
      base_ord = ord do asc :name, or_else: "Unknown" end
      combined = ord do asc base_ord end
    """
  end

  @doc """
  Error: {Prism, or_else} tuple already has or_else, can't use option too.
  """
  def redundant_or_else do
    """
    Invalid usage: {Prism, or_else} tuple already contains an or_else value.
    Do not also use the `or_else:` option.

    Choose one:
      1. Tuple syntax:
         asc {Prism.key(:score), 0}

      2. Option syntax:
         asc Prism.key(:score), or_else: 0

    Both are equivalent and normalize to the same form.
    """
  end

  @doc """
  Error: Projection type not recognized.
  """
  def invalid_projection_type(got) do
    """
    Invalid projection type.

    Expected one of:
      - atom                  (e.g., :name)
      - Lens                  (e.g., Lens.key(:name))
      - Prism                 (e.g., Prism.key(:score))
      - {Prism, or_else}      (e.g., {Prism.key(:score), 0})
      - function              (e.g., &String.length/1)
      - Behaviour module      (e.g., MyProjection)

    Got: #{inspect(got)}
    """
  end
end
