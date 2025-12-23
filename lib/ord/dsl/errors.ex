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
  Error: Captured function with `default:` option.
  """
  def default_with_captured_function do
    """
    The `default:` option cannot be used with captured functions.

    Use one of these alternatives:
      1. Create a 0-arity helper that returns a Prism:
         def score_prism, do: Prism.key(:score)
         asc score_prism(), default: 0

      2. Use inline Prism syntax:
         asc Prism.key(:score), default: 0

    Reason: Captured functions like &fun/1 don't expose their projection type
    at compile time, making default semantics ambiguous.
    """
  end

  @doc """
  Error: Anonymous function with `default:` option.
  """
  def default_with_anonymous_function do
    """
    The `default:` option cannot be used with anonymous functions.

    Use one of these alternatives:
      1. Create a 0-arity helper that returns a Prism:
         def score_prism, do: Prism.key(:score)
         asc score_prism(), default: 0

      2. Use inline Prism syntax:
         asc Prism.key(:score), default: 0

    Reason: Anonymous functions like `fn x -> x.field end` don't expose their
    projection type at compile time, making default semantics ambiguous.
    """
  end

  @doc """
  Error: Lens with `default:` option.
  """
  def default_with_lens do
    """
    The `default:` option is only valid with atoms or Prism projections, not with Lens.

    Reason: Lens guarantees focus on an existing value (or raises an error).
    Adding a default would violate this contract.

    If you need optional field handling, use a Prism instead:
      asc Prism.key(:name), default: "Unknown"

    Or use an atom with default (automatically becomes a Prism):
      asc :name, default: "Unknown"
    """
  end

  @doc """
  Error: Behaviour module with `default:` option.
  """
  def default_with_behaviour do
    """
    The `default:` option is only valid with atoms or Prism projections, not with Behaviour modules.

    Reason: Behaviour modules define custom projection logic that may not
    return Maybe values compatible with default handling.

    If you need default handling, implement it inside your Behaviour:
      defmodule MyProjection do
        @behaviour Funx.Ord.Dsl.Behaviour

        def project(value, opts) do
          value.field || Keyword.get(opts, :default, 0)
        end
      end
    """
  end

  @doc """
  Error: {Prism, default} tuple already has default, can't use option too.
  """
  def redundant_default do
    """
    Invalid usage: {Prism, default} tuple already contains a default value.
    Do not also use the `default:` option.

    Choose one:
      1. Tuple syntax:
         asc {Prism.key(:score), 0}

      2. Option syntax:
         asc Prism.key(:score), default: 0

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
      - {Prism, default}      (e.g., {Prism.key(:score), 0})
      - function              (e.g., &String.length/1)
      - Behaviour module      (e.g., MyProjection)

    Got: #{inspect(got)}
    """
  end

  @doc """
  Error: Module doesn't implement Funx.Ord.Dsl.Behaviour.
  """
  def missing_behaviour_implementation(module) do
    """
    Module #{inspect(module)} must implement Funx.Ord.Dsl.Behaviour.

    To fix, add this to your module:
      defmodule #{inspect(module)} do
        @behaviour Funx.Ord.Dsl.Behaviour

        @impl true
        def project(value, opts) do
          # Your projection logic here
        end
      end
    """
  end
end
