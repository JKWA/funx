defmodule Funx.Errors.ValidationError do
  @moduledoc """
  Represents a validation error in the Funx library.

  A `ValidationError` wraps one or more domain-level validation messages. It is typically used with `Either.Left` to indicate that a value failed validation and should not proceed in a computation. It can also be raised directly, as it implements the `Exception` behaviour.

  This module provides functions to construct, merge, and convert validation errors, enabling structured, composable error handling across pipelines and validation chains.

  ## Functions

  * `new/1` – Creates a `ValidationError` from a single error string or a list of error strings.
  * `empty/0` – Returns an empty `ValidationError`.
  * `merge/2` – Combines two `ValidationError` structs into one.
  * `from_tagged/1` – Converts a tagged error tuple (`{:error, errors}`) into a `ValidationError`.

  This module also implements the `Exception`, `String.Chars`, and `Funx.Summarizable` protocols, supporting both human-readable output and structured reporting.

  ### Usage in validation

  You can validate a value using a list of validator functions. Each validator returns an `Either.Right` if
  the check passes, or an `Either.Left` with an error message if it fails. If any validation fails,
  all errors are aggregated and returned in a single `Left`.

  In contexts where an error must halt execution, `ValidationError` can be raised directly using `raise/1`.

  ## Examples

  You can also use a `ValidationError` to hold errors:

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

  import Funx.Macros, only: [eq_for: 2, ord_for: 2]

  defstruct [:errors, __exception__: true]

  eq_for(Funx.Errors.ValidationError, :errors)
  ord_for(Funx.Errors.ValidationError, :errors)
  @behaviour Exception

  @type t :: %__MODULE__{errors: [String.t()]}

  @doc """
  Creates a `ValidationError` from a single string or list of strings.

  ## Examples

      iex> Funx.Errors.ValidationError.new("must be positive")
      %Funx.Errors.ValidationError{errors: ["must be positive"]}

      iex> Funx.Errors.ValidationError.new(["must be positive", "must be even"])
      %Funx.Errors.ValidationError{errors: ["must be positive", "must be even"]}
  """

  @spec new([String.t()]) :: t()
  def new(errors) when is_list(errors), do: %__MODULE__{errors: errors}

  @spec new(String.t()) :: t()
  def new(error), do: %__MODULE__{errors: [error]}

  @doc """
  Returns an empty `ValidationError`.

  ## Examples

      iex> Funx.Errors.ValidationError.empty()
      %Funx.Errors.ValidationError{errors: []}
  """
  @spec empty() :: t()
  def empty, do: %__MODULE__{errors: []}

  @doc """
  Merges two `ValidationError` structs into one by concatenating their error lists.

  ## Examples

      iex> e1 = Funx.Errors.ValidationError.new("must be positive")
      iex> e2 = Funx.Errors.ValidationError.new("must be even")
      iex> Funx.Errors.ValidationError.merge(e1, e2)
      %Funx.Errors.ValidationError{errors: ["must be positive", "must be even"]}
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{errors: e1}, %__MODULE__{errors: e2}),
    do: %__MODULE__{errors: e1 ++ e2}

  @doc """
  Converts a tagged error tuple into a `ValidationError`.

  ## Examples

      iex> Funx.Errors.ValidationError.from_tagged({:error, ["must be positive"]})
      %Funx.Errors.ValidationError{errors: ["must be positive"]}
  """
  @spec from_tagged({:error, [String.t()]}) :: t()
  def from_tagged({:error, errors}) when is_list(errors), do: new(errors)

  @impl Exception
  def exception(args) when is_list(args), do: struct(__MODULE__, args)

  @impl Exception
  def exception(message) when is_binary(message),
    do: %__MODULE__{errors: [message]}

  @impl Exception
  def message(%__MODULE__{errors: errors}) do
    Enum.map_join(errors, ", ", &to_string/1)
  end
end

defimpl Funx.Appendable, for: Funx.Errors.ValidationError do
  alias Funx.Errors.ValidationError

  def coerce(%ValidationError{errors: e}), do: ValidationError.new(e)

  def append(%ValidationError{} = acc, %ValidationError{} = other) do
    ValidationError.merge(acc, other)
  end
end

defimpl String.Chars, for: Funx.Errors.ValidationError do
  alias Funx.Errors.ValidationError

  def to_string(%ValidationError{errors: errors}) do
    "ValidationError(#{Enum.map_join(errors, ", ", &Kernel.to_string/1)})"
  end
end

defimpl Funx.Summarizable, for: Funx.Errors.ValidationError do
  def summarize(%{errors: value}), do: {:validation_error, Funx.Summarizable.summarize(value)}
end
