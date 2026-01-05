defmodule Funx.Validator.AllEqual do
  @moduledoc """
  Validates that all elements in a list are equal to each other.

  ## Maybe Support

  This validator supports `Maybe` types from Prism projections:
  - `Nothing` - Passes validation (optional fields without values)
  - `Just(list)` - Validates the list inside the Just

  This makes the validator compatible with optional fields in the validation DSL.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`
  - `:eq` - Custom equality comparator (defaults to `Funx.Eq.Protocol`)

  ## Examples

      iex> Funx.Validator.AllEqual.validate([1, 1, 1], [])
      %Funx.Monad.Either.Right{right: [1, 1, 1]}

      iex> Funx.Validator.AllEqual.validate([1, 2, 3], [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be all matching"]}}

      iex> Funx.Validator.AllEqual.validate("not a list", [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a list"]}}

      iex> Funx.Validator.AllEqual.validate([1, 2], [message: fn _ -> "all items must match" end])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["all items must match"]}}

  ## Using Custom Equality

  You can provide a custom equality comparator via the `:eq` option:

      iex> case_insensitive = %{
      ...>   eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
      ...>   not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      ...> }
      iex> Funx.Validator.AllEqual.validate(["HELLO", "hello", "HeLLo"], [eq: case_insensitive])
      %Funx.Monad.Either.Right{right: ["HELLO", "hello", "HeLLo"]}

  ## Maybe Examples

      iex> Funx.Validator.AllEqual.validate(%Funx.Monad.Maybe.Nothing{}, [])
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}

      iex> Funx.Validator.AllEqual.validate(%Funx.Monad.Maybe.Just{value: [1, 1, 1]}, [])
      %Funx.Monad.Either.Right{right: [1, 1, 1]}

      iex> Funx.Validator.AllEqual.validate(%Funx.Monad.Maybe.Just{value: [1, 2]}, [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be all matching"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.List
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  @impl true
  def validate(value, opts \\ [])

  # Skip Nothing values (optional fields without value)
  def validate(%Nothing{}, _opts) do
    Either.right(%Nothing{})
  end

  # Handle Just(list) - extract and validate the list
  def validate(%Just{value: list}, opts) when is_list(list) do
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)
    validate_list(list, opts, eq)
  end

  # Handle Just(non-list) - type error
  def validate(%Just{value: value}, opts) do
    message = build_message(opts, value, "must be a list")
    Either.left(ValidationError.new(message))
  end

  # Handle plain lists (backward compatibility)
  def validate(value, opts) when is_list(value) do
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)
    validate_list(value, opts, eq)
  end

  # Handle non-list, non-Maybe values
  def validate(value, opts) do
    message = build_message(opts, value, "must be a list")
    Either.left(ValidationError.new(message))
  end

  defp validate_list(value, opts, eq) do
    Either.lift_predicate(
      value,
      &all_elements_match?(&1, eq),
      fn v -> ValidationError.new(build_message(opts, v, "must be all matching")) end
    )
  end

  defp all_elements_match?(list, eq) do
    unique_count = list |> List.uniq(eq) |> length()
    unique_count == 1
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
