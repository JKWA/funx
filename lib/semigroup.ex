defprotocol Funx.Semigroup do
  @moduledoc """
  A protocol for combining values in a generic, extensible way.

  The `Semigroup` protocol defines how two values of the same type can be combined. It is
  used throughout Funx in functions like `traverse_a/2` and `wither_a/2` to accumulate
  intermediate results without coupling logic to a specific type.

  This protocol enables functions to remain flexible and composable when reducing,
  aggregating, or accumulating values across a wide variety of domains.

  ## Required functions

  * `coerce/1` – Normalizes an input value into a form suitable for aggregation.
  * `append/2` – Combines two values of the same type into one.

  ### Default - Flat list aggregation

  When using the default aggregation strategy, values are collected in a plain list:

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

  You can also use a custom struct to hold errors. This example uses `ValidationError`:

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
  Wraps a single value into the expected semigroup structure.
  """
  def coerce(term)

  @doc """
  Appends a value to an existing accumulator, combining both into a single result.

  This function defines how two semigroup elements are merged—whether by concatenating lists,
  merging structs, or another associative operation defined by the implementing type.
  """
  def append(accumulator, coerced)
end

defimpl Funx.Semigroup, for: Any do
  @spec coerce(term()) :: list()
  def coerce(value) when is_list(value), do: value
  def coerce(value), do: [value]

  @spec append(term(), term()) :: list()
  def append(acc, coerced), do: coerce(acc) ++ coerce(coerced)
end
