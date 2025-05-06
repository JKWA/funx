defprotocol Funx.Summarizable do
  @doc "Summarizes a value in a telemetry-safe, compact format."

  @fallback_to_any true

  @spec summarize(t) :: term()
  def summarize(value)
end

defimpl Funx.Summarizable, for: Any do
  def summarize(_), do: :unknown
end

defimpl Funx.Summarizable, for: Atom do
  def summarize(nil), do: nil
  def summarize(atom), do: {:atom, atom}
end

defimpl Funx.Summarizable, for: Integer do
  def summarize(value), do: {:integer, value}
end

defimpl Funx.Summarizable, for: Float do
  def summarize(value), do: {:float, value}
end

defimpl Funx.Summarizable, for: BitString do
  def summarize(value) when is_binary(value), do: {:binary, byte_size(value)}
  def summarize(value), do: {:bitstring, bit_size(value)}
end

defimpl Funx.Summarizable, for: List do
  def summarize([]), do: {:list, :empty}

  def summarize(list) do
    {:list, Enum.take(list, 3) |> Enum.map(&Funx.Summarizable.summarize/1)}
  end
end

defimpl Funx.Summarizable, for: Map do
  def summarize(map) when map_size(map) == 0, do: {:map, :empty}

  def summarize(map) do
    map
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.take(3)
    |> Enum.map(fn {k, v} -> {k, Funx.Summarizable.summarize(v)} end)
    |> then(&{:map, &1})
  end
end

defimpl Funx.Summarizable, for: Tuple do
  def summarize(tup) when tuple_size(tup) == 0, do: {:tuple, :empty}

  def summarize(tup) do
    tup
    |> Tuple.to_list()
    |> Enum.take(3)
    |> Enum.map(&Funx.Summarizable.summarize/1)
    |> then(&{:tuple, &1})
  end
end

defimpl Funx.Summarizable, for: Function do
  def summarize(_), do: :function
end

defimpl Funx.Summarizable, for: PID do
  def summarize(_), do: :pid
end

defimpl Funx.Summarizable, for: Port do
  def summarize(_), do: :port
end

defimpl Funx.Summarizable, for: Reference do
  def summarize(_), do: :reference
end

defimpl Funx.Summarizable, for: RuntimeError do
  def summarize(%RuntimeError{message: msg}), do: {:exception, {:runtime, msg}}
end

defimpl Funx.Summarizable, for: FunctionClauseError do
  def summarize(error),
    do: {:exception, {FunctionClauseError, Exception.message(error)}}
end
