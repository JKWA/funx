defprotocol Funx.Aggregatable do
  @moduledoc """
  A protocol for normalizing and combining values in a generic, extensible way.

  Within Funx, the Aggregatable protocol is used in `traverse_a/2` and `wither_a/2`.

  ## Required functions

    * `wrap/1` – Normalizes a single error value into the expected aggregation type.
    * `combine/2` – Merges a new value into an existing accumulator.

  ## Examples

  Validates a value using a list of validator functions. Each validator returns an `Either.Right` if
  the check passes, or an `Either.Left` with an error message if it fails. If any validation fails,
  all errors are aggregated and returned in a single `Left`.

  ### Flat list aggregation

  When using the default aggregation strategy, errors are collected in a plain list:

  ```elixir
  validate_positive = fn x ->
    Funx.Either.lift_predicate(x, &(&1 > 0), fn v -> "Value must be positive: " <> to_string(v) end)
  end

  validate_even = fn x ->
    Funx.Either.lift_predicate(x, &(rem(&1, 2) == 0), fn v -> "Value must be even: " <> to_string(v) end)
  end

  Funx.Either.validate(4, [validate_positive, validate_even])
  #=> %Funx.Either.Right{right: 4}

  Funx.Either.validate(3, [validate_positive, validate_even])
  #=> %Funx.Either.Left{left: ["Value must be even: 3"]}

  Funx.Either.validate(-3, [validate_positive, validate_even])
  #=> %Funx.Either.Left{left: ["Value must be positive: -3", "Value must be even: -3"]}
  ```

  ### Structured aggregation with `ValidationError`

  You can also use a custom struct to hold errors. This example uses `ValidationError` and a corresponding
  `Funx.Aggregatable` implementation to accumulate errors into a single structure:

  ```elixir
  alias Funx.Errors.ValidationError

  validate_positive = fn x ->
    Funx.Either.lift_predicate(x, &(&1 > 0), fn v -> "Value must be positive: " <> to_string(v) end)
    |> Funx.Either.map_left(&ValidationError.new/1)
  end

  validate_even = fn x ->
    Funx.Either.lift_predicate(x, &(rem(&1, 2) == 0), fn v -> "Value must be even: " <> to_string(v) end)
    |> Funx.Either.map_left(&ValidationError.new/1)
  end

  Funx.Either.validate(-3, [validate_positive, validate_even])
  #=> %Funx.Either.Left{
  #     left: %ValidationError{
  #       errors: ["Value must be positive: -3", "Value must be even: -3"]
  #     }
  #   }
  ```

  """

  @fallback_to_any true

  @doc """
  Wraps a single raw error into the expected aggregation structure.
  """
  def wrap(term)

  @doc """
  Combines a wrapped value with an existing accumulator of the same aggregation type.
  """
  def combine(accumulator, wrapped)
end

# defimpl Funx.Aggregatable, for: List do
#   @spec wrap(list()) :: list()
#   def wrap(value) when is_list(value), do: value
#   def wrap(value), do: [value]

#   @spec combine(list(), list()) :: list()
#   def combine(acc, wrapped), do: wrap(acc) ++ wrap(wrapped)
# end

defimpl Funx.Aggregatable, for: Any do
  alias Funx.List

  @spec wrap(term()) :: list()
  def wrap(value) when is_list(value), do: value
  def wrap(value), do: [value]

  @spec combine(term(), term()) :: list()
  def combine(acc, wrapped), do: List.concat([wrap(acc), wrap(wrapped)])
end
