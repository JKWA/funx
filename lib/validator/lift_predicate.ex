defmodule Funx.Validator.LiftPredicate do
  @moduledoc """
  Lifts a predicate into the validation context.

  `LiftPredicate` adapts a predicate function into a validator that conforms to
  `Funx.Validate.Behaviour`. It allows predicate-style logic to participate in
  the validation pipeline, producing `Either` results and `ValidationError`s
  instead of booleans.

  This module is intended as an escape hatch for ad-hoc or externally-defined
  predicates. For reusable domain rules, prefer defining a dedicated validator
  module or using the Predicate DSL directly.

  Options

  - `:pred` (required)
    A predicate function `(value -> boolean)` that determines whether validation
    succeeds.

  - `:message` (optional)
    A callback `(value -> String.t())` used to override the default error message
    when the predicate fails.

  Semantics

  - If the predicate returns `true`, validation succeeds and the value is returned.
  - If the predicate returns `false`, validation fails with a `ValidationError`.
  - `Nothing` values succeed without invoking the predicate.
  - `Just` values are unwrapped before validation.
  .
  Examples

      iex> Funx.Validator.LiftPredicate.validate(150, pred: fn v -> v > 100 end)
      %Funx.Monad.Either.Right{right: 150}

      iex> Funx.Validator.LiftPredicate.validate(50, pred: fn v -> v > 100 end)
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{errors: ["invalid value"]}
      }

      iex> Funx.Validator.LiftPredicate.validate(
      ...>   50,
      ...>   pred: fn v -> v > 100 end,
      ...>   message: fn _ -> "must be greater than 100" end
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{errors: ["must be greater than 100"]}
      }
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator

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

  def validate(%Just{value: value}, opts, _env) do
    validate_number(value, opts)
  end

  def validate(value, opts, _env) do
    validate_number(value, opts)
  end

  defp validate_number(value, opts) do
    pred = Keyword.get(opts, :pred)

    if is_nil(pred) do
      raise ArgumentError, "LiftPredicate validator requires a :pred option"
    end

    Either.lift_predicate(
      value,
      fn v -> pred.(v) end,
      fn v -> Validator.validation_error(opts, v, "invalid value") end
    )
  end
end
