defmodule Funx.Validator do
  @moduledoc ~S"""
  Built-in validators for common validation scenarios.

  All validators implement the `Funx.Validate.Behaviour` contract and expose
  `validate(input, opts, env)`. Convenience arities are provided for direct usage
  and delegate to `validate/3`, allowing validators to compose cleanly with
  `Funx.Monad.Either.validate/2`.

  ## Available Validators

  ### Presence and Structure
  - `Funx.Validator.Required` – Validates presence (not `nil`, not empty, not `Nothing`)
  - `Funx.Validator.Confirmation` – Validates that a value matches another field using `Eq`

  ### String Validators
  - `Funx.Validator.Email` – Validates basic email format
  - `Funx.Validator.MinLength` – Validates minimum string length
  - `Funx.Validator.MaxLength` – Validates maximum string length
  - `Funx.Validator.Pattern` – Validates against a regular expression

  ### Numeric Validators
  - `Funx.Validator.Integer` – Validates that the value is an integer
  - `Funx.Validator.Negative` – Validates number < 0
  - `Funx.Validator.Positive` – Validates number > 0
  - `Funx.Validator.Range` – Validates number within inclusive bounds

  ### Equality (Eq based)
  - `Funx.Validator.Equal` – Validates that a value equals an expected value using `Eq`
  - `Funx.Validator.NotEqual` – Validates that a value does not equal an expected value using `Eq`
  - `Funx.Validator.AllEqual` – Validates that all elements in a collection are equal using `Eq`

  ### Ordering (Ord based)
  - `Funx.Validator.GreaterThan` – Validates value > threshold
  - `Funx.Validator.GreaterThanOrEqual` – Validates value ≥ threshold
  - `Funx.Validator.LessThan` – Validates value < threshold
  - `Funx.Validator.LessThanOrEqual` – Validates value ≤ threshold

  ### Membership (Eq based)
  - `Funx.Validator.In` – Validates membership in a set of allowed values using `Eq`
  - `Funx.Validator.NotIn` – Validates non-membership in a set of disallowed values using `Eq`

  ### Combinators
  - `Funx.Validator.Any` – Validates that at least one of several validators succeeds (OR logic)
  - `Funx.Validator.Not` – Negates the result of another validator

  ### Predicate Lifting
  - `Funx.Validator.LiftPredicate` – Lifts a predicate function into a validator

  ## Message Customization

      iex> result =
      ...>   Funx.Validator.Required.validate(
      ...>     nil,
      ...>     [message: fn _ -> "Name is required" end]
      ...>   )
      iex> Funx.Monad.Either.left?(result)
      true

      iex> result =
      ...>   Funx.Validator.MinLength.validate(
      ...>     "hi",
      ...>     [min: 5, message: fn val -> "'#{val}' is too short" end]
      ...>   )
      iex> Funx.Monad.Either.left?(result)
      true

  ## Usage

      iex> Funx.Validator.Required.validate("hello")
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.MinLength.validate("hello", [min: 3])
      %Funx.Monad.Either.Right{right: "hello"}

  ## Usage with Either.validate

      iex> validators = [
      ...>   &Funx.Validator.Required.validate/1,
      ...>   &Funx.Validator.Email.validate/1,
      ...>   fn v -> Funx.Validator.MinLength.validate(v, [min: 5]) end
      ...> ]
      iex> result = Funx.Monad.Either.validate("user@example.com", validators)
      iex> Funx.Monad.Either.right?(result)
      true
  """
end
