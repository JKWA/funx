defmodule Funx.Ord.Any do
  @moduledoc """
  Provides default ordering functions using the `Funx.Ord.Protocol`.

  This module delegates to the protocol implementation for the given type,
  falling back to Elixir's built-in comparison operators when no protocol
  implementation exists.
  """

  alias Funx.Ord.Protocol

  @doc """
  Returns `true` if `a` is less than `b` according to their `Ord.Protocol` implementation.

  ## Examples

      iex> Funx.Ord.Any.lt?(1, 2)
      true

      iex> Funx.Ord.Any.lt?(2, 1)
      false
  """
  @spec lt?(any(), any()) :: boolean()
  def lt?(a, b), do: Protocol.lt?(a, b)

  @doc """
  Returns `true` if `a` is less than or equal to `b`.

  ## Examples

      iex> Funx.Ord.Any.le?(1, 2)
      true

      iex> Funx.Ord.Any.le?(2, 2)
      true
  """
  @spec le?(any(), any()) :: boolean()
  def le?(a, b), do: Protocol.le?(a, b)

  @doc """
  Returns `true` if `a` is greater than `b`.

  ## Examples

      iex> Funx.Ord.Any.gt?(2, 1)
      true

      iex> Funx.Ord.Any.gt?(1, 2)
      false
  """
  @spec gt?(any(), any()) :: boolean()
  def gt?(a, b), do: Protocol.gt?(a, b)

  @doc """
  Returns `true` if `a` is greater than or equal to `b`.

  ## Examples

      iex> Funx.Ord.Any.ge?(2, 1)
      true

      iex> Funx.Ord.Any.ge?(2, 2)
      true
  """
  @spec ge?(any(), any()) :: boolean()
  def ge?(a, b), do: Protocol.ge?(a, b)
end
