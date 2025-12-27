defmodule Funx.Eq.Dsl.Parser do
  @moduledoc false
  # Internal parser for Eq DSL - converts AST into Step and Block structs
  #
  # ## Normalization Contract
  #
  # This parser normalizes all projection syntax into one of four canonical types
  # that contramap/2 accepts:
  #
  #   1. Lens.t()              - bare Lens struct
  #   2. Prism.t()             - bare Prism struct
  #   3. {Prism.t(), or_else}  - Prism with or_else value
  #   4. (a -> b)              - projection function
  #
  # All syntax sugar resolves to these types:
  #
  #   - :atom              → Prism.key(:atom)
  #   - :atom, or_else: x  → {Prism.key(:atom), x}
  #   - Lens.key(...)      → Lens.key(...) (pass through)
  #   - Prism.key(...)     → Prism.key(...) (pass through)
  #   - {Prism, x}         → {Prism, x} (pass through)
  #   - fn -> ... end      → fn -> ... end (pass through)
  #   - Behaviour          → fn v -> Behaviour.project(v, []) end
  #
  # ## Nesting Support
  #
  # Unlike Ord DSL, Eq DSL supports nested blocks:
  #
  #   - any do ... end     → Block with strategy: :any
  #   - all do ... end     → Block with strategy: :all
  #
  # These create a tree structure instead of a flat list.
  #
  # contramap/2 is the ONLY place that converts optics to functions.
  # The parser never creates function wrappers around optics.

  alias Funx.Eq.Dsl.{Block, Errors, Step}
  alias Funx.Optics.Prism

  @doc """
  Parse a DSL block into a list of Step/Block nodes
  """
  def parse_operations(block, caller_env) do
    block
    |> extract_operations()
    |> Enum.map(&parse_entry_to_node(&1, caller_env))
  end

  defp extract_operations({:__block__, _meta, lines}) when is_list(lines), do: lines
  defp extract_operations(single_line), do: [single_line]

  # Parse "on value, opt: val" or "on value" or "not_on value"
  defp parse_entry_to_node({directive, meta, [[do: block]]}, caller_env)
       when directive in [:any, :all] do
    children = parse_operations(block, caller_env)
    metadata = extract_meta(meta)
    Block.new(directive, children, metadata)
  end

  defp parse_entry_to_node({directive, meta, [projection_value, opts]}, caller_env)
       when directive in [:on, :not_on] and is_list(opts) do
    negate = directive == :not_on
    parse_projection(projection_value, opts, negate, meta, caller_env)
  end

  defp parse_entry_to_node({directive, meta, [projection_value]}, caller_env)
       when directive in [:on, :not_on] do
    negate = directive == :not_on
    parse_projection(projection_value, [], negate, meta, caller_env)
  end

  defp parse_entry_to_node(other, _caller_env) do
    raise CompileError, description: Errors.invalid_dsl_syntax(other)
  end

  defp parse_projection(projection_value, opts, negate, meta, caller_env) do
    or_else = Keyword.get(opts, :or_else)
    custom_eq = Keyword.get(opts, :eq)

    projection_ast = build_projection_ast(projection_value, or_else, meta, caller_env)
    eq_ast = custom_eq || quote(do: Funx.Eq)
    metadata = extract_meta(meta)

    Step.new(projection_ast, eq_ast, negate, metadata)
  end

  # Atom without or_else
  defp build_projection_ast(atom, nil, _meta, _caller_env) when is_atom(atom) do
    quote do
      Prism.key(unquote(atom))
    end
  end

  # Atom with or_else
  defp build_projection_ast(atom, or_else, _meta, _caller_env)
       when is_atom(atom) and not is_nil(or_else) do
    quote do
      {Prism.key(unquote(atom)), unquote(or_else)}
    end
  end

  # Captured function
  defp build_projection_ast({:&, _, _} = fun_ast, or_else, meta, _caller_env) do
    if is_nil(or_else) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_captured_function()
    end
  end

  # Anonymous function
  defp build_projection_ast({:fn, _, _} = fun_ast, or_else, meta, _caller_env) do
    if is_nil(or_else) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_anonymous_function()
    end
  end

  # Helper function call (0-arity)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, _}, _]}, _, args} = fun_ast,
         or_else,
         _meta,
         _caller_env
       )
       when args == [] or is_nil(args) do
    if is_nil(or_else) do
      fun_ast
    else
      quote do
        {unquote(fun_ast), unquote(or_else)}
      end
    end
  end

  # Lens.key
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :key]}, _, _} = lens_ast,
         or_else,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  # Lens.path
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :path]}, _, _} = lens_ast,
         or_else,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  # Prism (any Prism function)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Prism]}, _]}, _, _} = prism_ast,
         or_else,
         _meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      prism_ast
    else
      quote do
        {unquote(prism_ast), unquote(or_else)}
      end
    end
  end

  # Traversal (any Traversal function)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Traversal]}, _]}, _, _} = traversal_ast,
         or_else,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      traversal_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_traversal()
    end
  end

  # Tuple with prism and or_else
  defp build_projection_ast({prism_ast, or_else_ast}, nil, _meta, _caller_env) do
    quote do
      {unquote(prism_ast), unquote(or_else_ast)}
    end
  end

  defp build_projection_ast({_prism_ast, _or_else_ast}, _extra_or_else, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.redundant_or_else()
  end

  # Module (either struct or behaviour)
  defp build_projection_ast({:__aliases__, _, _} = module_alias, or_else, meta, caller_env) do
    unless is_nil(or_else) do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_behaviour()
    end

    expanded_module = Macro.expand(module_alias, caller_env)

    if function_exported?(expanded_module, :__struct__, 0) do
      build_struct_filter_ast(expanded_module)
    else
      build_behaviour_projection_ast(expanded_module, meta)
    end
  end

  # Unknown projection type
  defp build_projection_ast(other, _or_else, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.invalid_projection_type(other)
  end

  defp build_struct_filter_ast(struct_module) do
    quote do
      fn
        %unquote(struct_module){} -> true
        _ -> false
      end
    end
  end

  defp build_behaviour_projection_ast(behaviour_module, meta) do
    validate_behaviour_implementation!(behaviour_module, meta)

    quote do
      fn value -> unquote(behaviour_module).project(value, []) end
    end
  end

  defp validate_behaviour_implementation!(module, meta) do
    Code.ensure_compiled!(module)
    behaviours = module.module_info(:attributes)[:behaviour] || []

    unless Funx.Eq.Dsl.Behaviour in behaviours do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.missing_behaviour_implementation(module)
    end

    :ok
  end

  defp extract_meta(meta) when is_list(meta) do
    %{
      line: Keyword.get(meta, :line),
      column: Keyword.get(meta, :column)
    }
  end
end
