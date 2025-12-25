defmodule Funx.Macros.Errors do
  @moduledoc false
  # Centralized error messages for Funx.Macros
  #
  # ## Error Message Contract
  #
  # These messages are part of the public API. Changes should be:
  # 1. Documented in CHANGELOG
  # 2. Reflected in tests
  # 3. Considered breaking changes if semantics change
  #
  # Each error has:
  # - Clear category (option misuse, type mismatch)
  # - Actionable guidance (what to do instead)
  # - Examples when helpful

  @doc """
  Error: Lens with `or_else:` option.
  """
  def or_else_with_lens do
    """
    The `or_else:` option cannot be used with Lens. Lens provides total access and always returns a value.

    Reason: Lens guarantees focus on an existing value (or raises an error).
    Adding an or_else would violate this contract.

    If you need optional field handling, use a Prism instead:
      Funx.Macros.ord_for(MyStruct, Prism.key(:name), or_else: "Unknown")

    Or use an atom with or_else (automatically becomes a Prism):
      Funx.Macros.ord_for(MyStruct, :name, or_else: "Unknown")
    """
  end

  @doc """
  Error: Captured function with `or_else:` option.
  """
  def or_else_with_captured_function do
    """
    The `or_else:` option cannot be used with captured functions. Functions must handle their own defaults.

    Use one of these alternatives:
      1. Use a Prism with or_else:
         Funx.Macros.ord_for(MyStruct, Prism.key(:score), or_else: 0)

      2. Handle defaults inside the function:
         Funx.Macros.ord_for(MyStruct, fn x -> x.score || 0 end)

    Reason: Captured functions like &fun/1 don't expose their projection type
    at compile time, making or_else semantics ambiguous.
    """
  end

  @doc """
  Error: Anonymous function with `or_else:` option.
  """
  def or_else_with_anonymous_function do
    """
    The `or_else:` option cannot be used with anonymous functions. Functions must handle their own defaults.

    Use one of these alternatives:
      1. Use a Prism with or_else:
         Funx.Macros.ord_for(MyStruct, Prism.key(:field), or_else: default)

      2. Handle defaults inside the function:
         Funx.Macros.ord_for(MyStruct, fn x -> x.field || default end)

    Reason: Anonymous functions like `fn x -> x.field end` don't expose their
    projection type at compile time, making or_else semantics ambiguous.
    """
  end

  @doc """
  Error: Struct literal with `or_else:` option.
  """
  def or_else_with_struct_literal do
    """
    The `or_else:` option cannot be used with struct literals. Use explicit {Prism, default} syntax if needed.

    If your struct literal is a Lens:
      # Lens always returns a value, so or_else doesn't make sense
      Funx.Macros.ord_for(MyStruct, %Lens{...})

    If you need or_else handling, use a Prism instead:
      # Define a Prism that can fail
      @my_prism %Prism{
        preview: fn value -> ... end,
        review: fn value -> ... end
      }
      Funx.Macros.ord_for(MyStruct, {@my_prism, default_value})

    Reason: Struct literals don't clearly indicate whether they represent
    total (Lens) or partial (Prism) access at compile time.
    """
  end

  @doc """
  Error: {Prism, or_else} tuple already has or_else, can't use option too.
  """
  def redundant_or_else do
    """
    Redundant or_else option. The projection already includes a default value as {Prism, default}.

    Choose one:
      1. Tuple syntax:
         Funx.Macros.ord_for(MyStruct, {Prism.key(:score), 0})

      2. Option syntax:
         Funx.Macros.ord_for(MyStruct, Prism.key(:score), or_else: 0)

    Both are equivalent and normalize to the same form.
    Do not use both at the same time.
    """
  end
end
