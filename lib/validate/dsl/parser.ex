defmodule Funx.Validate.Dsl.Parser do
  @moduledoc false
  # Compile-time parser that converts Validation DSL syntax into Step nodes.
  #
  # ## Syntax Recognition
  #
  # The parser recognizes these forms:
  #
  #   - Bare validator                        → Step{optic: nil, validators: [validator]}
  #   - at :key, validator                    → Step{optic: :key, validators: [validator]}
  #   - at [:a, :b], validator                → Step{optic: Prism.path([:a, :b]), validators: [validator]}
  #   - at :key, [v1, v2]                     → Step{optic: :key, validators: [v1, v2]}
  #   - at Lens.key(:key), validator          → Step{optic: Lens, validators: [validator]}
  #   - at Prism.key(:key), validator         → Step{optic: Prism, validators: [validator]}
  #
  # ## Validator Specs
  #
  #   - Module: Required
  #   - Tuple: {MinLength, min: 3}
  #   - List: [Required, {MinLength, min: 3}, Email]

  alias Funx.Optics.Prism
  alias Funx.Validate.Dsl.{Errors, Step}

  @doc """
  Parse a DSL block into a list of Step nodes.
  """
  def parse_steps(block, caller_env) do
    block
    |> extract_statements()
    |> Enum.map(&parse_statement(&1, caller_env))
  end

  defp extract_statements({:__block__, _meta, statements}) when is_list(statements) do
    statements
  end

  defp extract_statements(single_statement), do: [single_statement]

  # Parse "at optic_or_key, validator_spec"
  defp parse_statement({:at, meta, [optic_or_key, validator_spec]}, _caller_env) do
    validate_validator_spec!(validator_spec)
    optic = normalize_optic(optic_or_key)
    metadata = extract_meta(meta)
    Step.new_projected(optic, validator_spec, metadata)
  end

  # Parse bare validator (root validator)
  defp parse_statement(validator_spec, _caller_env) do
    validate_validator_spec!(validator_spec)
    Step.new_root(validator_spec, %{})
  end

  # Normalize optic expressions
  # Atom keys default to Prism.key
  defp normalize_optic(key) when is_atom(key) do
    quote do
      Prism.key(unquote(key))
    end
  end

  # Lists default to Prism.path (supports nested keys and structs)
  defp normalize_optic(list) when is_list(list) do
    quote do
      Prism.path(unquote(list))
    end
  end

  # Explicit optic expression (Lens.key(:x), Prism.key(:x), etc.)
  defp normalize_optic(optic_expr), do: optic_expr

  defp extract_meta(meta) do
    %{
      line: Keyword.get(meta, :line)
    }
  end

  # ============================================================================
  # COMPILE-TIME VALIDATION
  # ============================================================================

  # Validate a validator spec at compile time
  # Module alias (e.g., Required, Email)
  defp validate_validator_spec!({:__aliases__, _, _}), do: :ok

  # Tuple with module and options: {MinLength, min: 3}
  defp validate_validator_spec!({module_or_fn, opts}) when is_list(opts) do
    validate_validator_spec!(module_or_fn)
  end

  # List of validators
  defp validate_validator_spec!(validators) when is_list(validators) do
    if validators == [] do
      raise_empty_validator_list()
    else
      Enum.each(validators, &validate_validator_in_list!/1)
    end
  end

  # Function capture: &my_function/1
  defp validate_validator_spec!({:&, _, _}), do: :ok

  # Anonymous function: fn x -> ... end
  defp validate_validator_spec!({:fn, _, _}), do: :ok

  # Variable or function call
  defp validate_validator_spec!({name, _, context})
       when is_atom(name) and (is_atom(context) or is_list(context)),
       do: :ok

  # Qualified function call: Module.function(...)
  defp validate_validator_spec!({{:., _, _}, _, _}), do: :ok

  # Reject literal numbers
  defp validate_validator_spec!(literal) when is_number(literal) do
    raise_invalid_validator(literal)
  end

  # Reject literal strings
  defp validate_validator_spec!(literal) when is_binary(literal) do
    raise_invalid_validator(literal)
  end

  # Reject literal atoms (that aren't module aliases, which are handled above)
  defp validate_validator_spec!(literal) when is_atom(literal) do
    raise_invalid_validator(literal)
  end

  # Validate items within a validator list
  # Module alias
  defp validate_validator_in_list!({:__aliases__, _, _}), do: :ok

  # Tuple with module and options
  defp validate_validator_in_list!({module_or_fn, opts}) when is_list(opts) do
    validate_validator_in_list!(module_or_fn)
  end

  # Function capture
  defp validate_validator_in_list!({:&, _, _}), do: :ok

  # Anonymous function
  defp validate_validator_in_list!({:fn, _, _}), do: :ok

  # Variable or function call
  defp validate_validator_in_list!({name, _, context})
       when is_atom(name) and (is_atom(context) or is_list(context)),
       do: :ok

  # Qualified function call
  defp validate_validator_in_list!({{:., _, _}, _, _}), do: :ok

  # Reject literal numbers
  defp validate_validator_in_list!(literal) when is_number(literal) do
    raise_invalid_validator_in_list(literal)
  end

  # Reject literal strings
  defp validate_validator_in_list!(literal) when is_binary(literal) do
    raise_invalid_validator_in_list(literal)
  end

  # Reject literal atoms
  defp validate_validator_in_list!(literal) when is_atom(literal) do
    raise_invalid_validator_in_list(literal)
  end

  # Reject nested lists
  defp validate_validator_in_list!(list) when is_list(list) do
    raise_invalid_validator_in_list(list)
  end

  # ============================================================================
  # ERROR HELPERS
  # ============================================================================

  defp raise_invalid_validator(literal) do
    raise CompileError, description: Errors.invalid_validator_error(literal)
  end

  defp raise_empty_validator_list do
    raise CompileError, description: Errors.empty_validator_list_error()
  end

  defp raise_invalid_validator_in_list(literal) do
    raise CompileError, description: Errors.invalid_validator_in_list_error(literal)
  end
end
