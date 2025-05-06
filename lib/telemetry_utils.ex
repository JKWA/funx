defmodule Funx.TelemetryUtils do
  @moduledoc """
  The `Funx.TelemetryUtils` module provides utility functions for summarizing values in a safe,
  telemetry-friendly manner. It ensures that various data types can be represented concisely
  and safely, making it suitable for telemetry and debugging use cases.

  This module handles a wide range of data types, including primitive types, collections,
  and system-specific types. For complex data structures, it provides summaries, such as
  counts or partial views, instead of full details. This approach minimizes overhead and
  prevents potential crashes or deep introspections.

  ### Examples

      iex> Funx.TelemetryUtils.summarize(42)
      {:integer, 42}

      iex> Funx.TelemetryUtils.summarize("hello")
      {:binary, 5}

      iex> Funx.TelemetryUtils.summarize([1, 2, 3, 4, 5])
      {:list, [{:integer, 1}, {:integer, 2}, {:integer, 3}]}

      iex> Funx.TelemetryUtils.summarize(%{a: 1, b: "text", c: :atom})
      {:map, [a: {:integer, 1}, b: {:binary, 4}, c: {:atom, :atom}]}

      iex> Funx.TelemetryUtils.summarize({:ok, "data", 123})
      {:tuple, [{:atom, :ok}, {:binary, 4}, {:integer, 123}]}

  """

  @doc """
  Summarizes a given `value` in a type-safe manner, providing concise metadata for each type.

  ### Supported Summaries

    * **Primitive types**: Returns atoms with the type and value for `nil`, atoms, integers, and floats.
    * **Binary**: Returns `{:binary, size}` for byte-aligned binaries.
    * **Bitstring**: Returns `{:bitstring, bit_size}` for non-byte-aligned bitstrings.
    * **Lists**: Returns `{:list, [...]}` containing the first three summarized elements or `:empty` for empty lists.
    * **Maps**: Returns `{:map, [...]}` with up to three summarized key-value pairs, sorted by key, or `:empty` for empty maps.
    * **Tuples**: Returns `{:tuple, [...]}` with up to three summarized elements or `:empty` for empty tuples.
    * **System-specific types**: Includes representations for `:function`, `:pid`, `:port`, and `:reference`.
    * **Unknown types**: Returns `:unknown` for types that do not match any other pattern.

  ### Examples

      iex> Funx.TelemetryUtils.summarize("hello")
      {:binary, 5}

      iex> Funx.TelemetryUtils.summarize(%{key: fn -> :ok end})
      {:map, [key: :function]}

      iex> Funx.TelemetryUtils.summarize(nil)
      nil

  ### Parameters

    - `value`: The value to be summarized. This can be of any type.

  ### Returns

    - A tuple in the form `{:type, metadata}`, where metadata varies based on the type.
    - Returns `:unknown` if `value` does not match any recognized pattern.

  """
  @spec summarize(term()) ::
          nil
          | {:atom, atom()}
          | {:integer, integer()}
          | {:float, float()}
          | {:binary, non_neg_integer()}
          | {:bitstring, non_neg_integer()}
          | {:list, list(term())}
          | {:map, list({term(), term()})}
          | {:tuple, list(term())}
          | :function
          | :pid
          | :port
          | :reference
          | :unknown

  # Primitive types
  def summarize(nil), do: nil
  def summarize(value) when is_atom(value), do: {:atom, value}
  def summarize(value) when is_integer(value), do: {:integer, value}
  def summarize(value) when is_float(value), do: {:float, value}

  # Byte-aligned binaries
  def summarize(value) when is_binary(value), do: {:binary, byte_size(value)}

  # Non-byte-aligned bitstrings
  def summarize(value) when is_bitstring(value), do: {:bitstring, bit_size(value)}

  def summarize(%Funx.Either.Left{left: value}), do: summarize(value)
  def summarize(%Funx.Either.Right{right: value}), do: summarize(value)

  def summarize(%RuntimeError{message: msg}), do: {:exception, {:runtime, msg}}

  def summarize(%FunctionClauseError{} = error),
    do: {:exception, {FunctionClauseError, Exception.message(error)}}

  # Lists with controlled sampling and recursive summarization
  def summarize([]), do: {:list, :empty}

  def summarize(list) when is_list(list),
    do: {:list, Enum.take(list, 3) |> Enum.map(&summarize/1)}

  # Maps with controlled sampling of key-value pairs and recursive summarization
  def summarize(map) when is_map(map) and map_size(map) == 0, do: {:map, :empty}

  def summarize(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.take(3)
    |> Enum.map(fn {k, v} -> {k, summarize(v)} end)
    |> then(&{:map, &1})
  end

  # Tuples with controlled sampling of elements
  def summarize(tuple) when is_tuple(tuple) and tuple_size(tuple) == 0, do: {:tuple, :empty}

  def summarize(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.take(3)
    |> Enum.map(&summarize/1)
    |> then(&{:tuple, &1})
  end

  # System-specific types
  def summarize(value) when is_function(value), do: :function
  def summarize(value) when is_pid(value), do: :pid
  def summarize(value) when is_port(value), do: :port
  def summarize(value) when is_reference(value), do: :reference

  # Catch-all for possible unknown types (cannot test this line)
  # coveralls-ignore-start
  def summarize(_), do: :unknown
  # coveralls-ignore-stop
end
