defmodule Funx.Validator.MinLength do
  @moduledoc """
  Validates that a string meets a minimum length requirement.

  ## Required Options

  - `:min` - Minimum length (integer)

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.MinLength.validate("hello", min: 3)
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.MinLength.validate("hi", min: 5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at least 5 characters"]}}
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

  def validate(%Just{value: string}, opts, _env) when is_binary(string) do
    validate_string(string, opts)
  end

  def validate(%Just{value: value}, opts, _env) do
    message = build_message(opts, value, "must be a string")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts, _env) when is_binary(value) do
    validate_string(value, opts)
  end

  def validate(value, opts, _env) do
    message = build_message(opts, value, "must be a string")
    Either.left(ValidationError.new(message))
  end

  defp validate_string(value, opts) do
    min = Keyword.fetch!(opts, :min)

    Either.lift_predicate(
      value,
      fn v -> String.length(v) >= min end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be at least #{min} characters"))
      end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
