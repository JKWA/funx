defmodule Funx.Errors.EffectError do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ferrors%2Feffect_error.livemd)

  Represents a system-level failure in an effectful computation.

  `EffectError` is raised or returned when a failure occurs during the execution
  of an `Effect` stage, such as `map`, `bind`, or `ap`. It is not meant for user-facing
  validation, but rather for internal tracing, telemetry, and diagnostics.

  ## Fields

    * `stage` – the name of the effect stage where the error occurred (`:map`, `:bind`, `:ap`, etc.)
    * `reason` – the term (often an exception) that caused the failure

  This error implements the `Exception`, `String.Chars`, and `Funx.Summarizable` behaviours.
  """
  @enforce_keys [:stage, :reason]
  defstruct [:stage, :reason, __exception__: true]

  @behaviour Exception

  @type t :: %__MODULE__{
          stage: atom(),
          reason: any()
        }

  @doc """
  Creates a new `EffectError` from the given stage and reason.

  ## Examples

      iex> Funx.Errors.EffectError.new(:bind, %RuntimeError{message: "boom"})
      %Funx.Errors.EffectError{stage: :bind, reason: %RuntimeError{message: "boom"}}
  """
  @spec new(atom(), any()) :: t()
  def new(stage, reason), do: %__MODULE__{stage: stage, reason: reason}

  @impl Exception
  def exception(%{stage: stage, reason: reason}) when is_atom(stage),
    do: %__MODULE__{stage: stage, reason: reason}

  @impl Exception
  def message(%__MODULE__{stage: stage, reason: reason}) when is_atom(stage) do
    "EffectError at #{stage}: #{Exception.message(reason)}"
  rescue
    _ -> "EffectError at #{stage}: #{inspect(reason)}"
  end
end

defimpl String.Chars, for: Funx.Errors.EffectError do
  def to_string(%Funx.Errors.EffectError{stage: stage, reason: reason}) do
    "EffectError(#{stage}: #{inspect(reason)})"
  end
end

defimpl Funx.Summarizable, for: Funx.Errors.EffectError do
  def summarize(%{stage: stage, reason: reason}) do
    {:effect_error, [stage: stage, reason: Funx.Summarizable.summarize(reason)]}
  end
end
