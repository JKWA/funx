defmodule Funx.Monad.Either.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Either DSL compile-time errors

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

    Use 'bind', 'map', 'ap', or Either functions.
    """
  end

  @doc """
  Error when a bare function call is used instead of bind/map
  """
  def invalid_function_error(func_name, allowed_functions) do
    """
    Invalid operation: #{func_name}

    Bare function calls are not allowed in the DSL pipeline.

    If you meant to call an Either function, only these are allowed:
      #{inspect(allowed_functions)}

    If you meant to use a custom function:

      Use 'bind' if the operation can fail:
        bind #{func_name}(...)

      Use 'map' if the operation is a pure transformation:
        map #{func_name}(...)

    Or use a function capture:
      map &#{func_name}/1

    Or create a module implementing Funx.Monad.Behaviour.Bind or Funx.Monad.Behaviour.Map.
    """
  end

  @doc """
  Error when a literal value is used in a validator list
  """
  def invalid_validator_error(literal) do
    """
    Invalid validator in list: #{inspect(literal)}

    Validator lists must contain only:
      - Module names: MyValidator
      - Module with options: {MyValidator, opts}
      - Function calls: my_function()
      - Function captures: &my_function/1
      - Anonymous functions: fn x -> ... end

    Literals (numbers, strings, maps, etc.) are not allowed.
    """
  end
end
