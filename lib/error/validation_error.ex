defmodule Funx.Errors.ValidationError do
  @moduledoc """
  Represents a validation error in the Funx library.

  A `ValidationError` wraps one or more domain-level validation messages. This struct is used in conjunction with `Either.Left` to signal that a value failed validation and should not proceed in a computation.

  Functions are provided to construct, merge, and convert validation errors, enabling structured, composable error handling.

  ## Functions

    * `new/1` – Creates a `ValidationError` from a single error string or a list of error strings.
    * `empty/0` – Returns an empty `ValidationError`.
    * `merge/2` – Combines two `ValidationError` structs into one.
    * `from_tagged/1` – Converts a tagged error tuple (`{:error, errors}`) into a `ValidationError`.

  This module also implements the `String.Chars` and `Funx.Summarizable` protocols for human-readable output and structured reporting.
  """

  defstruct [:errors]

  @type t :: %__MODULE__{errors: [String.t()]}

  @doc """
  Creates a `ValidationError` from a single string or list of strings.

  ## Examples

      iex> Funx.Errors.ValidationError.new("must be positive")
      %Funx.Errors.ValidationError{errors: ["must be positive"]}

      iex> Funx.Errors.ValidationError.new(["must be positive", "must be even"])
      %Funx.Errors.ValidationError{errors: ["must be positive", "must be even"]}
  """
  @spec new(String.t()) :: t()
  def new(error) when is_binary(error), do: %__MODULE__{errors: [error]}

  @spec new([String.t()]) :: t()
  def new(errors) when is_list(errors), do: %__MODULE__{errors: errors}

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
end

defimpl String.Chars, for: Funx.Errors.ValidationError do
  def to_string(%Funx.Errors.ValidationError{errors: errors}) do
    "ValidationError(#{Enum.map_join(errors, ", ", &Kernel.to_string/1)})"
  end
end

defimpl Funx.Summarizable, for: Funx.Errors.ValidationError do
  def summarize(%{errors: value}), do: {:validation_error, Funx.Summarizable.summarize(value)}
end
