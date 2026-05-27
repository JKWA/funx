defmodule Funx.Validator.Atom do
  @moduledoc """
  Validates that a value is an atom.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Atom.validate(:ok)
      %Funx.Monad.Either.Right{right: :ok}

      iex> Funx.Validator.Atom.validate(:error)
      %Funx.Monad.Either.Right{right: :error}

      iex> Funx.Validator.Atom.validate("atom")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be an atom"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Atom.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be an atom"
  end
end
