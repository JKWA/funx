defmodule Funx.Validator.Integer do
  @moduledoc """
  Validates that a value is an integer.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Integer.validate(5)
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.Integer.validate(5.5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be an integer"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  # Convenience overloads for easier direct usage
  def validate(value) do
    validate(value, [], %{})
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  # Behaviour implementation (arity-3)
  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{}, _opts, _env) do
    Either.right(%Nothing{})
  end

  def validate(%Just{value: inner_value}, opts, _env) do
    validate_value(inner_value, opts)
  end

  def validate(value, opts, _env) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    Either.lift_predicate(
      value,
      fn v -> is_integer(v) end,
      fn v -> ValidationError.new(build_message(opts, v, "must be an integer")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
