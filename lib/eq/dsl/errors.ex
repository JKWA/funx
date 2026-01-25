defmodule Funx.Eq.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Eq DSL
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
  Error: Captured function with `or_else:` option.
  """
  def or_else_with_captured_function do
    """
    The `or_else:` option cannot be used with captured functions.

    Use one of these alternatives:
      1. Create a 0-arity helper that returns a Prism:
         def score_prism, do: Prism.key(:score)
         on score_prism(), or_else: 0

      2. Use inline Prism syntax:
         on Prism.key(:score), or_else: 0

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
         on score_prism(), or_else: 0

      2. Use inline Prism syntax:
         on Prism.key(:score), or_else: 0

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
      on Prism.key(:name), or_else: "Unknown"

    Or use an atom with or_else (automatically becomes a Prism):
      on :name, or_else: "Unknown"
    """
  end

  @doc """
  Error: Traversal with `or_else:` option.
  """
  def or_else_with_traversal do
    """
    The `or_else:` option is not supported with Traversal projections.

    Reason: Traversal focuses on multiple values. The semantics of or_else
    with multiple foci would be ambiguous (apply to each focus? to the list?).

    If you need optional handling, wrap individual optics in the Traversal:
      Traversal.combine([
        {Prism.key(:field1), default1},
        {Prism.key(:field2), default2}
      ])
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
        @behaviour Funx.Eq.Dsl.Behaviour

        def project(value, opts) do
          value.field || Keyword.get(opts, :or_else, 0)
        end
      end
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
         on {Prism.key(:score), 0}

      2. Option syntax:
         on Prism.key(:score), or_else: 0

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

  @doc """
  Error: Bare module reference without eq/1 behaviour.
  """
  def bare_module_without_behaviour(module) do
    """
    Bare module reference #{inspect(module)} does not implement Eq.Dsl.Behaviour.

    Module atoms are not Eq maps and will cause a runtime error.

    To fix, choose one of:
      1. Implement the Eq.Dsl.Behaviour:
         @behaviour Funx.Eq.Dsl.Behaviour
         def eq(_opts), do: Funx.Eq.contramap(& &1.id)

      2. Use tuple syntax to pass options:
         {#{inspect(module)}, []}

      3. Call a function explicitly:
         #{inspect(module)}.my_eq_function()

      4. Use a variable or captured function instead:
         my_eq  # where my_eq is bound to an Eq map
    """
  end
end
