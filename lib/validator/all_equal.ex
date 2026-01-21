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

  use Funx.Validator

  alias Funx.List

  @impl Funx.Validator
  def valid?(list, opts, _env) when is_list(list) do
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)
    all_elements_match?(list, eq)
  end

  def valid?(_non_list, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, _opts) when is_list(value) do
    "must be all matching"
  end

  def default_message(_value, _opts) do
    "must be a list"
  end

  defp all_elements_match?(list, eq) do
    unique_count = list |> List.uniq(eq) |> length()
    unique_count == 1
  end
end
