defmodule Funx.Validator do
  @moduledoc """
  Built-in validators for common validation scenarios.

  All validators implement the `Funx.Validation.Behaviour` contract.

  ## Available Validators

  ### String Validators
  - `Email` - Validates basic email format
  - `MaxLength` - Validates maximum string length
  - `MinLength` - Validates minimum string length
  - `Pattern` - Validates against a regular expression
  - `Required` - Validates presence (not nil, not empty, not Nothing)

  ### Numeric Validators
  - `Integer` - Validates value is an integer
  - `Negative` - Validates number < 0
  - `Positive` - Validates number > 0
  - `Range` - Validates number within inclusive bounds

  ### Combinators
  - `Any` - Validates that at least one of several validators succeeds (OR logic)
  - `Not` - Validates that a validator does not succeed (negation)

  ### Other Validators
  - `AllEqual` - Validates that all elements in a list are equal
  - `Confirmation` - Validates field matches another field
  - `In` - Validates membership in a list of allowed values
  - `LiftPredicate` - Lifts a predicate function into a validator

  ## Message Customization

  All validators support custom error messages via the `:message` option:

  ```elixir
  # Static message
  Required.validate(nil, [message: "Name is required"], %{})

  # Dynamic message (function receives the value)
  MinLength.validate("hi", [min: 5, message: fn val -> "'\#{val}' is too short" end], %{})
  ```

  ## Usage

  ```elixir
  alias Funx.Validator.{Required, Email, MinLength}

  # Direct usage
  Required.validate("hello", [], %{})
  #=> %Right{right: "hello"}

  # With options
  MinLength.validate("hello", [min: 3], %{})
  #=> %Right{right: "hello"}

  # With Either.validate
  validators = [
    &Required.validate(&1, [], %{}),
    &Email.validate(&1, [], %{}),
    &MinLength.validate(&1, [min: 5], %{})
  ]
  Either.validate("user@example.com", validators)
  ```
  """

  # Note: No default validate/2 delegate - use specific validators

  # Convenience aliases for importing
  alias Funx.Validator.AllEqual
  alias Funx.Validator.Any
  alias Funx.Validator.Confirmation
  alias Funx.Validator.Email
  alias Funx.Validator.GreaterThan
  alias Funx.Validator.GreaterThanOrEqual
  alias Funx.Validator.In
  alias Funx.Validator.Integer
  alias Funx.Validator.LessThan
  alias Funx.Validator.LessThanOrEqual
  alias Funx.Validator.LiftPredicate
  alias Funx.Validator.MaxLength
  alias Funx.Validator.MinLength
  alias Funx.Validator.Negative
  alias Funx.Validator.Not
  alias Funx.Validator.NotEqual
  alias Funx.Validator.NotIn
  alias Funx.Validator.Pattern
  alias Funx.Validator.Positive
  alias Funx.Validator.Range
  alias Funx.Validator.Required

  @doc false
  def __validators__ do
    [
      AllEqual,
      Any,
      Confirmation,
      Email,
      GreaterThan,
      GreaterThanOrEqual,
      In,
      Integer,
      LessThan,
      LessThanOrEqual,
      LiftPredicate,
      MaxLength,
      MinLength,
      Negative,
      Not,
      NotEqual,
      NotIn,
      Pattern,
      Positive,
      Range,
      Required
    ]
  end
end
