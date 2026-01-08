defmodule Funx.Validator.In do
  @moduledoc """
  Validates that a value is a member of a given collection using an `Eq`
  comparator.

  `In` enforces a membership constraint of the form:
  "value must be one of these".

  Membership is defined by an `Eq` instance, not by structural equality or
  Elixir’s `in` operator.

  Options

  - `:values` (required)
    The list of allowed values to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())`.

  Semantics

  - Succeeds if the value equals any element in `:values` under `Eq`.
  - Fails otherwise.
  - `Nothing` passes through.
  - `Just` is unwrapped before comparison.

  Examples

      iex> Funx.Validator.In.validate("active", values: ["active", "inactive", "pending"])
      %Funx.Monad.Either.Right{right: "active"}

      iex> Funx.Validator.In.validate("deleted", values: ["active", "inactive"])
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be one of: \\"active\\", \\"inactive\\""]
        }
      }

      iex> Funx.Validator.In.validate(:ok, values: [:ok, :error])
      %Funx.Monad.Either.Right{right: :ok}

      iex> Funx.Validator.In.validate(%Funx.Monad.Maybe.Nothing{}, values: ["a", "b"])
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}

      iex> Funx.Validator.In.validate(
      ...>   %Funx.Monad.Maybe.Just{value: "active"},
      ...>   values: ["active", "inactive"]
      ...> )
      %Funx.Monad.Either.Right{right: "active"}

      iex> Funx.Validator.In.validate(
      ...>   %Funx.Monad.Maybe.Just{value: "deleted"},
      ...>   values: ["active", "inactive"]
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be one of: \\"active\\", \\"inactive\\""]
        }
      }
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.List
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  def validate(value) do
    validate(value, [])
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  @impl true
  def validate(value, opts, _env)

  def validate(%Nothing{} = value, _opts, _env) do
    Either.right(value)
  end

  def validate(%Just{value: v}, opts, _env) do
    validate_value(v, opts)
  end

  def validate(value, opts, _env) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    values = Keyword.fetch!(opts, :values)
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)

    Either.lift_predicate(
      value,
      fn v -> List.elem?(values, v, eq) end,
      fn v ->
        rendered = Enum.map_join(values, ", ", &inspect/1)
        ValidationError.new(build_message(opts, v, "must be one of: #{rendered}"))
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
