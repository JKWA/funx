defmodule Funx.Validator.Each do
  @moduledoc """
  Validates that every element in a list passes a given validator (or validators).

  `Each` provides universal quantification over list elements. It applies one or more
  validators to each element and collects all errors using applicative semantics.

  ## Options

  Exactly one of the following must be provided:

  - `:validator` - A single validator to apply to each element
  - `:validators` - A list of validators; each element must pass all of them

  Each validator may be:
  - A validator module implementing `Funx.Validate.Behaviour`
  - A `{Validator, opts}` tuple for optioned validators
  - A validator function with arity 1, 2, or 3

  ## Semantics

  - Uses `traverse_a` for applicative error collection (all failures reported)
  - Empty lists pass validation (vacuous truth)
  - `Nothing` passes through unchanged
  - `Just(list)` unwraps and validates the list

  ## Examples

      iex> Funx.Validator.Each.validate([1, 2, 3], validator: Funx.Validator.Positive)
      %Funx.Monad.Either.Right{right: [1, 2, 3]}

      iex> Funx.Validator.Each.validate([1, 2, 3], validators: [Funx.Validator.Positive, Funx.Validator.Integer])
      %Funx.Monad.Either.Right{right: [1, 2, 3]}

  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  def validate(value), do: validate(value, [])
  def validate(value, opts), do: validate(value, opts, %{})

  @impl true
  def validate(%Nothing{}, _opts, _env), do: Either.right(%Nothing{})

  def validate(%Just{value: list}, opts, env), do: validate(list, opts, env)

  def validate(list, opts, _env) when is_list(list) do
    validators = normalize_validators!(opts)

    Either.traverse_a(list, fn item ->
      validate_item(item, validators)
    end)
  end

  def validate(_non_list, opts, _env) do
    message = Funx.Validator.build_message(opts, nil, "must be a list")
    Either.left(ValidationError.new(message))
  end

  defp normalize_validators!(opts) do
    has_validator = Keyword.has_key?(opts, :validator)
    has_validators = Keyword.has_key?(opts, :validators)

    case {has_validator, has_validators} do
      {false, false} ->
        raise ArgumentError, "Each validator requires :validator or :validators option"

      {true, true} ->
        raise ArgumentError, "Each validator accepts :validator or :validators, not both"

      {true, false} ->
        [Keyword.fetch!(opts, :validator)]

      {false, true} ->
        Keyword.fetch!(opts, :validators)
    end
  end

  defp validate_item(item, validators) do
    Either.traverse_a(validators, fn validator ->
      run(validator, item)
    end)
    |> Monad.map(fn _ -> item end)
  end

  defp run({validator, opts}, value) when is_atom(validator) do
    validator.validate(value, opts, %{})
  end

  defp run(validator, value) when is_atom(validator) do
    validator.validate(value, [], %{})
  end

  defp run(func, value) when is_function(func, 1), do: func.(value)
  defp run(func, value) when is_function(func, 2), do: func.(value, [])
  defp run(func, value) when is_function(func, 3), do: func.(value, [], %{})
end
