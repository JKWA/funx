defprotocol Funx.Appendable do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fappendable%2Fappendable.livemd)

  A protocol for combining values in a generic, extensible way.

  The `Appendable` protocol defines how two values of the same type can be combined. It is
  used throughout Funx in functions like `traverse_a/2` and `wither_a/2` to accumulate
  intermediate results without coupling logic to a specific type.

  This protocol enables functions to remain flexible and composable when reducing,
  aggregating, or accumulating values across a wide variety of domains.

  ## Required functions

  * `coerce/1` – Normalizes an input value into a form suitable for aggregation.
  * `append/2` – Combines two values of the same type into one.

  ### Default – Flat list aggregation

  A fallback implementation is provided for all types that do not define a specific
  `Appendable` instance. This default uses list concatenation as a universal aggregation
  strategy: all inputs are coerced into lists (if not already), and combined using `++`.

  When using the default aggregation strategy, values are collected in a plain list:

  ```elixir
  validate_positive = fn x ->
    Funx.Monad.Either.lift_predicate(x, &(&1 > 0), fn v -> "Value must be positive: " <> to_string(v) end)
  end

  validate_even = fn x ->
    Funx.Monad.Either.lift_predicate(x, &(rem(&1, 2) == 0), fn v -> "Value must be even: " <> to_string(v) end)
  end

  Funx.Monad.Either.validate(4, [validate_positive, validate_even])
  #=> %Funx.Monad.Either.Right{right: 4}

  Funx.Monad.Either.validate(3, [validate_positive, validate_even])
  #=> %Funx.Monad.Either.Left{left: ["Value must be even: 3"]}

  Funx.Monad.Either.validate(-3, [validate_positive, validate_even])
  #=> %Funx.Monad.Either.Left{left: ["Value must be positive: -3", "Value must be even: -3"]}
  ```

  ### Structured aggregation with `ValidationError`

  You can also use a custom struct to hold errors. This example uses `ValidationError`:

  ```elixir
  alias Funx.Errors.ValidationError

  validate_positive = fn x ->
    Funx.Monad.Either.lift_predicate(x, &(&1 > 0), fn v -> "Value must be positive: " <> to_string(v) end)
    |> Funx.Monad.Either.map_left(&ValidationError.new/1)
  end

  validate_even = fn x ->
    Funx.Monad.Either.lift_predicate(x, &(rem(&1, 2) == 0), fn v -> "Value must be even: " <> to_string(v) end)
    |> Funx.Monad.Either.map_left(&ValidationError.new/1)
  end

  Funx.Monad.Either.validate(-3, [validate_positive, validate_even])
  #=> %Funx.Monad.Either.Left{
  #     left: %ValidationError{
  #       errors: ["Value must be positive: -3", "Value must be even: -3"]
  #     }
  #   }
  ```

  """

  @fallback_to_any true

  @doc """
  Normalizes a single input value into a form suitable for accumulation.
  """
  def coerce(term)

  @doc """
  Combines two values into a single result.

  Implementations must ensure the operation is associative within their type. For types
  that require disambiguation or structural control, define a custom implementation.
  """
  def append(accumulator, coerced)
end

defimpl Funx.Appendable, for: Any do
  @spec coerce(term()) :: list()
  def coerce(value) when is_list(value), do: value
  def coerce(value), do: [value]

  @spec append(term(), term()) :: list()
  def append(acc, coerced), do: coerce(acc) ++ coerce(coerced)
end
