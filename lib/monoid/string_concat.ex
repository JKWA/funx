defmodule Funx.Monoid.StringConcat do
  @moduledoc """
  A Monoid implementation for concatenating strings.

  This monoid uses binary string concatenation (`<>`) as its associative operation
  and `""` (empty string) as the identity element.
  """

  @type t :: %__MODULE__{value: String.t()}

  defstruct value: ""
end

defimpl Funx.Monoid, for: Funx.Monoid.StringConcat do
  alias Funx.Monoid.StringConcat

  @spec empty(StringConcat.t()) :: StringConcat.t()
  def empty(_), do: %StringConcat{value: ""}

  @spec append(StringConcat.t(), StringConcat.t()) :: StringConcat.t()
  def append(%StringConcat{value: a}, %StringConcat{value: b}) do
    %StringConcat{value: a <> b}
  end

  @spec wrap(StringConcat.t(), String.t()) :: StringConcat.t()
  def wrap(%StringConcat{}, value) when is_binary(value), do: %StringConcat{value: value}

  @spec unwrap(StringConcat.t()) :: String.t()
  def unwrap(%StringConcat{value: value}), do: value
end
