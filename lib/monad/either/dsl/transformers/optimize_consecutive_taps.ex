defmodule Funx.Monad.Either.Dsl.Transformers.OptimizeConsecutiveTaps do
  @moduledoc """
  Optimizes consecutive `tap` operations, keeping only the last one.

  Since `tap` operations don't modify the value (they only perform side effects),
  consecutive taps can be optimized by keeping only the last one.

  ## Example

      # Before transformation:
      either value do
        bind GetUser
        tap &Logger.info/1
        tap &IO.inspect/1  # This tap replaces the previous one
        map Transform
      end

      # After transformation:
      either value do
        bind GetUser
        tap &IO.inspect/1  # Only the last tap is kept
        map Transform
      end

  This is safe because:
  - Taps don't modify the value
  - Only the final tap's side effect matters
  - Earlier taps are redundant

  ## Usage

      either value, transformers: [OptimizeConsecutiveTaps] do
        ...
      end
  """

  @behaviour Funx.Monad.Either.Dsl.Transformer

  alias Funx.Monad.Either.Dsl.Step

  @impl true
  def transform(steps, _opts) do
    optimized_steps = optimize_taps(steps, [])
    {:ok, optimized_steps}
  end

  # Recursively optimize consecutive taps
  defp optimize_taps([], acc), do: Enum.reverse(acc)

  defp optimize_taps([step | rest], acc) do
    case step do
      %Step.EitherFunction{function: :tap} ->
        # Collect all consecutive taps
        {taps, remaining} = collect_taps([step | rest])
        # Keep only the last tap
        last_tap = List.last(taps)
        optimize_taps(remaining, [last_tap | acc])

      other_step ->
        optimize_taps(rest, [other_step | acc])
    end
  end

  # Collect consecutive tap operations
  defp collect_taps(steps) do
    Enum.split_while(steps, fn
      %Step.EitherFunction{function: :tap} -> true
      _ -> false
    end)
  end
end
