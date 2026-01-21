defmodule Funx.Validator.GreaterThan do
  @moduledoc """
  Validates that a value is strictly greater than a given reference value
  using an `Ord` comparator.

  `GreaterThan` enforces an ordering constraint of the form:
  "value must be greater than X".

  Ordering is defined by an `Ord` instance, not by numeric comparison or
  structural operators.

  Options

  - `:value` (required)
    The reference value to compare against.

  - `:ord` (optional)
    An ordering comparator. Defaults to `Funx.Ord.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value compares as `:gt` relative to the reference value under
    the given `Ord`, validation succeeds.
  - If the value compares as `:lt` or `:eq`, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before comparison.

  Examples

      iex> Funx.Validator.GreaterThan.validate(7, value: 5)
      %Funx.Monad.Either.Right{right: 7}

      iex> Funx.Validator.GreaterThan.validate("b", value: "a")
      %Funx.Monad.Either.Right{right: "b"}

      iex> Funx.Validator.GreaterThan.validate("a", value: "a")
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be greater than \\\"a\\\""]
        }
      }

      iex> Funx.Validator.GreaterThan.validate(%Funx.Monad.Maybe.Nothing{}, value: 5)
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}
  """

  use Funx.Validator

  alias Funx.Ord

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    reference = Keyword.fetch!(opts, :value)
    ord = Keyword.get(opts, :ord, Ord.Protocol)
    Ord.compare(value, reference, ord) == :gt
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    reference = Keyword.fetch!(opts, :value)
    "must be greater than #{inspect(reference)}"
  end
end
