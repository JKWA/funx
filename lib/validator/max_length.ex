defmodule Funx.Validator.MaxLength do
  @moduledoc """
  Validates that a string does not exceed a maximum length.

  ## Required Options

  - `:max` - Maximum length (integer)

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.MaxLength.validate("hi", [max: 5])
      %Funx.Monad.Either.Right{right: "hi"}

      iex> Funx.Validator.MaxLength.validate("hello world", [max: 5])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at most 5 characters"]}}

      iex> Funx.Validator.MaxLength.validate("hello world", [max: 5, message: fn val -> "'\#{val}' is too long" end])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["'hello world' is too long"]}}
  """

  @behaviour Funx.Validate.Behaviour

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
    max = Keyword.fetch!(opts, :max)

    Either.lift_predicate(
      value,
      fn v -> String.length(v) <= max end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be at most #{max} characters"))
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
