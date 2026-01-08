defmodule Funx.Validator.Not do
  @moduledoc """
  Validates that a given validator does not succeed.

  `Not` provides logical negation for validation. It inverts the success and failure
  of a single validator while preserving inapplicability semantics for optional
  (`Prism`) foci.

  This validator is useful for expressing constraints such as:
  “value must not satisfy rule A”.

  Options

  - `:validator` (required)
    A single validator to negate. This may be:
    - a validator module implementing `Funx.Validate.Behaviour`
    - a `{Validator, opts}` tuple for optioned validators

  - `:message` (optional)
    A zero-arity callback `(() -> String.t())` used to override the default error
    message when the negated validator succeeds.

  Semantics

  - The inner validator is evaluated first.
  - If the inner validator returns `Left`, `Not` succeeds and returns the original value.
  - If the inner validator returns `Right`, `Not` fails with a `ValidationError`.
  - `Nothing` values are preserved and never cause failure.
  - `Just` values are validated by the inner validator, but the original input is
    returned unchanged on success.

  Examples

      iex> Funx.Validator.Not.validate(0,
      ...>   validator: Funx.Validator.Positive
      ...> )
      %Funx.Monad.Either.Right{right: 0}

      iex> Funx.Validator.Not.validate(10,
      ...>   validator: Funx.Validator.Positive
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must not satisfy condition"]
        }
      }

      iex> Funx.Validator.Not.validate(%Funx.Monad.Maybe.Nothing{},
      ...>   validator: Funx.Validator.Positive
      ...> )
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}

      iex> Funx.Validator.Not.validate(10,
      ...>   validator: Funx.Validator.Positive,
      ...>   message: fn -> "must not be positive" end
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must not be positive"]
        }
      }
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad
  alias Funx.Monad.Either

  # Convenience overload for easier direct usage
  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  # Behaviour implementation (arity-3)
  @impl true
  def validate(value, opts, env) do
    validator = Keyword.fetch!(opts, :validator)
    result = run(validator, value, env)

    case result do
      %Either.Right{right: %Monad.Maybe.Nothing{}} ->
        # Nothing means "not applicable" - preserve it unchanged
        result

      other ->
        other
        |> Either.flip()
        |> Monad.map(fn _ -> value end)
        |> finalize(opts)
    end
  end

  defp run({validator, opts}, value, env) do
    validator.validate(value, opts, env)
  end

  defp run(validator, value, env) do
    validator.validate(value, [], env)
  end

  defp finalize(%Either.Right{} = ok, _opts), do: ok

  defp finalize(%Either.Left{}, opts) do
    message =
      case Keyword.get(opts, :message) do
        nil -> "must not satisfy condition"
        callback -> callback.()
      end

    Either.left(ValidationError.new(message))
  end
end
