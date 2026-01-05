defmodule Funx.Validator.Any do
  @moduledoc """
  Validates that at least one of several alternative validators succeeds.

  `Any` provides disjunctive validation semantics. Unlike the default validation
  pipeline, which is conjunctive (all validators must succeed), `Any` succeeds
  as soon as a single validator passes. If all validators fail, validation fails
  with a single aggregated `ValidationError`.

  This validator is useful for expressing alternatives such as:
  “value must satisfy rule A or rule B”.

  Options

  - `:validators` (required)
    A non-empty list of validators. Each entry may be:
    - a validator module implementing `Funx.Validation.Behaviour`
    - a `{Validator, opts}` tuple for optioned validators

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

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

  @impl true
  def validate(value, opts \\ []) do
    validators = Keyword.get(opts, :validators)

    if is_nil(validators) do
      raise ArgumentError, "Any validator requires a :validators option"
    end

    validators
    |> Either.traverse(fn validation ->
      run(validation, value) |> Either.flip()
    end)
    |> Either.flip()
    |> finalize(opts)
  end

  defp run({validator, opts}, value) do
    validator.validate(value, opts)
  end

  defp run(validator, value) do
    validator.validate(value, [])
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
