defmodule Funx.Validator.Confirmation do
  @moduledoc """
  Validates that a value matches another field in the data structure.

  Useful for password confirmation, email confirmation, etc.

  ## Required Options

  - `:field` - The field name to compare against (atom)
  - `:data` - The full data structure containing both fields

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> data = %{password: "secret", password_confirmation: "secret"}
      iex> Funx.Validator.Confirmation.validate("secret", field: :password, data: data)
      %Funx.Monad.Either.Right{right: "secret"}

      iex> data = %{password: "secret", password_confirmation: "wrong"}
      iex> Funx.Validator.Confirmation.validate("wrong", field: :password, data: data)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["does not match password"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  # Convenience overload for default opts (raises on missing required options)
  def validate(value) do
    validate(value, [])
  end

  # Convenience overload for easier direct usage
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
    field = Keyword.fetch!(opts, :field)
    data = Keyword.fetch!(opts, :data)
    original_value = Map.get(data, field)

    Either.lift_predicate(
      value,
      fn v -> v == original_value end,
      fn v -> ValidationError.new(build_message(opts, v, "does not match #{field}")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
