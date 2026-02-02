defmodule Funx.Validator.Any do
  @moduledoc """
  Validates that at least one of several alternative validators succeeds.

  `Any` provides disjunctive validation semantics. Unlike the default validation
  pipeline, which is conjunctive (all validators must succeed), `Any` succeeds
  as soon as a single validator passes. If all validators fail, validation fails
  with a single aggregated `ValidationError`.

  This validator is useful for expressing alternatives such as:
  "value must satisfy rule A or rule B".

  Options

  - `:validators` (required)
    A non-empty list of validators. Each entry may be:
    - a validator module implementing `Funx.Validate.Behaviour`
    - a `{Validator, opts}` tuple for optioned validators
    - a validator function with arity 1, 2, or 3 (e.g., result of `validate do...end`)
    - a `{validator_function, opts}` tuple for optioned function validators

  - `:message` (optional)
    A zero-arity callback `(() -> String.t())` used to override the default error
    message when all alternatives fail.

  Semantics

  - Validators are evaluated left-to-right.
  - Evaluation short-circuits on the first successful validation.
  - If any validator returns `Right`, the value is returned unchanged.
  - If all validators return `Left`, a single `ValidationError` is returned.
  - `Nothing` values succeed if any validator accepts them.
  - `Just` values are unwrapped before validation.

  Examples

      iex> Funx.Validator.Any.validate(10,
      ...>   validators: [Funx.Validator.Positive, Funx.Validator.Negative]
      ...> )
      %Funx.Monad.Either.Right{right: 10}

      iex> Funx.Validator.Any.validate(0,
      ...>   validators: [Funx.Validator.Positive, Funx.Validator.Negative]
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["value must satisfy at least one alternative"]
        }
      }

      iex> Funx.Validator.Any.validate(0,
      ...>   validators: [Funx.Validator.Positive, Funx.Validator.Negative],
      ...>   message: fn -> "must be positive or negative" end
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be positive or negative"]
        }
      }
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

  def validate(value) do
    validate(value, [])
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  @impl true
  def validate(value, opts, env) do
    validators = Keyword.get(opts, :validators)

    if is_nil(validators) do
      raise ArgumentError, "Any validator requires a :validators option"
    end

    validators
    |> Either.traverse(fn validation ->
      run(validation, value, env) |> Either.flip()
    end)
    |> Either.flip()
    |> finalize(opts)
  end

  defp run({validator, opts}, value, env) do
    cond do
      is_function(validator, 3) -> validator.(value, opts, env)
      is_function(validator, 2) -> validator.(value, opts)
      is_function(validator, 1) -> validator.(value)
      true -> validator.validate(value, opts, env)
    end
  end

  defp run(validator, value, env) do
    cond do
      is_function(validator, 3) -> validator.(value, [], env)
      is_function(validator, 2) -> validator.(value, [])
      is_function(validator, 1) -> validator.(value)
      true -> validator.validate(value, [], env)
    end
  end

  defp finalize(%Either.Right{} = ok, _opts), do: ok

  defp finalize(%Either.Left{}, opts) do
    message =
      case Keyword.get(opts, :message) do
        nil -> "value must satisfy at least one alternative"
        callback -> callback.()
      end

    Either.left(ValidationError.new(message))
  end
end
