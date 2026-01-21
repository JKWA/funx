defmodule Funx.Monad.Maybe.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Maybe DSL compile-time errors

  @doc """
  Error when a bare module is used without a keyword (bind/map/ap)
  """
  def bare_module_error(module_alias) do
    """
    Invalid operation: #{Macro.to_string(module_alias)}

    Modules must be used with a keyword:
      bind #{Macro.to_string(module_alias)}
      map #{Macro.to_string(module_alias)}
      ap #{Macro.to_string(module_alias)}
    """
  end

  @doc """
  Error when an invalid operation is used in the DSL
  """
  def invalid_operation_error(operation) do
    """
    Invalid operation: #{inspect(operation)}

    Use 'bind', 'map', 'ap', or Maybe functions.
    """
  end

  @doc """
  Error when a bare function call is used instead of bind/map
  """
  def invalid_function_error(func_name, allowed_functions) do
    """
    Invalid operation: #{func_name}

    Bare function calls are not allowed in the DSL pipeline.

    If you meant to call a Maybe function, only these are allowed:
      #{inspect(allowed_functions)}

    If you meant to use a custom function, you must use 'bind' or 'map':
      bind #{func_name}(...)
      map #{func_name}(...)

    Or use a function capture:
      map &#{func_name}/1

    Or create a module that implements the appropriate behavior:
      - Funx.Monad.Behaviour.Bind for bind operations
      - Funx.Monad.Behaviour.Map for map operations
      - Funx.Monad.Behaviour.Predicate for filter operations
    """
  end

  @doc """
  Error when a module returns an invalid result type during execution
  """
  def invalid_result_error(result, meta, operation_type) do
    location = format_location(meta)
    op_info = if operation_type, do: " in #{operation_type} operation", else: ""

    """
    Module bind/3, map/3, or predicate/3 callback must return a Maybe struct, Either struct, result tuple, or nil#{op_info}.#{location}
    Got: #{inspect(result)}

    Expected return types:
      - Maybe: just(value) or nothing()
      - Either: right(value) or left(error)
      - Result tuple: {:ok, value} or {:error, reason}
      - nil (lifted to nothing())
    """
  end

  # ============================================================================
  # METADATA FORMATTING
  # ============================================================================

  defp format_location(nil), do: ""

  defp format_location(%{line: line, column: column})
       when not is_nil(line) and not is_nil(column) do
    "\n  at line #{line}, column #{column}"
  end

  defp format_location(%{line: line}) when not is_nil(line) do
    "\n  at line #{line}"
  end

  defp format_location(_), do: ""
end
