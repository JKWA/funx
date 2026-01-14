defmodule Funx.Validate.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Validate DSL compile-time errors

  @doc """
  Error when a literal value is used as a validator
  """
  def invalid_validator_error(literal) do
    """
    Invalid validator: #{inspect(literal)}

    Validators must be one of:
      - Module names: Required, Email, MinLength
      - Module with options: {MinLength, min: 3}
      - List of validators: [Required, Email]
      - Function calls: my_validator()
      - Function captures: &my_validator/1
      - Anonymous functions: fn x -> ... end

    Literals (numbers, strings, atoms) are not allowed.
    """
  end

  @doc """
  Error when an empty list is used as a validator
  """
  def empty_validator_list_error do
    """
    Invalid validator: empty list []

    Validator lists must contain at least one validator.

    If you meant to make validation optional, use a validator that handles Nothing:
      at :field, MyOptionalValidator
    """
  end

  @doc """
  Error when a literal value is used in a validator list
  """
  def invalid_validator_in_list_error(literal) do
    """
    Invalid validator in list: #{inspect(literal)}

    Validator lists must contain only:
      - Module names: Required, Email
      - Module with options: {MinLength, min: 3}
      - Function calls: my_validator()
      - Function captures: &my_validator/1
      - Anonymous functions: fn x -> ... end

    Literals (numbers, strings, atoms) are not allowed.
    """
  end
end
