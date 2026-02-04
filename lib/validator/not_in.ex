defmodule Funx.Validator.NotIn do
  @moduledoc """
  Validates that a value is not a member of a given collection using an `Eq`
  comparator.

  `NotIn` enforces an exclusion constraint of the form:
  “value must not be one of these”.

  Membership is defined by an `Eq` instance, not by structural equality or
  Elixir’s `in` operator.

  Options

  - `:values` (required)
    The list of disallowed values.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value matches any element in `:values` under `Eq`, validation fails.
  - If the value does not match any element, validation succeeds.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before comparison.

  Examples

    iex> Funx.Validator.NotIn.validate("deleted", values: ["active", "inactive"])
    %Funx.Monad.Either.Right{right: "deleted"}

    iex> Funx.Validator.NotIn.validate("active", values: ["active", "inactive"])
    %Funx.Monad.Either.Left{
      left: %Funx.Errors.ValidationError{
        errors: ["must not be one of: [\\\"active\\\", \\\"inactive\\\"]"]
      }
    }

    iex> Funx.Validator.NotIn.validate(%Funx.Monad.Maybe.Nothing{}, values: ["a", "b"])
    %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.NotIn.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    values = Keyword.fetch!(opts, :values)
    "must not be one of: #{inspect(values)}"
  end
end
