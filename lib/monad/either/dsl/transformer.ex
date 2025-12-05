defmodule Funx.Monad.Either.Dsl.Transformer do
  @moduledoc """
  Behaviour for transforming Either DSL pipelines after parsing.

  Transformers allow post-parse optimization and validation of the pipeline.
  They receive a list of Step structs and can modify, validate, or optimize them.

  ## Compile-Time Dependencies

  ⚠️ Transformers run at **compile time** and create compile-time dependencies.

  When you use a transformer:

      either user_id, transformers: [MyTransformer] do
        bind GetUser
      end

  The `MyTransformer.transform/2` function is called during macro expansion.
  This means:

  - The transformer output is baked into the compiled code
  - Changes to the transformer may require recompiling modules that use it
  - Run `mix clean && mix compile` if transformer changes aren't reflected

  This is intentional and allows for compile-time optimization. The DSL
  uses `Code.ensure_compiled!/1` to track these dependencies, so most changes
  will trigger automatic recompilation.

  ## Example

      defmodule OptimizeConsecutiveTaps do
        @behaviour Funx.Monad.Either.Dsl.Transformer

        @impl true
        def transform(steps, _opts) do
          # Optimize consecutive tap operations
          optimized_steps = optimize_taps(steps, [])
          {:ok, optimized_steps}
        end

        defp optimize_taps([], acc), do: Enum.reverse(acc)

        defp optimize_taps([step | rest], acc) do
          case step do
            %Step.EitherFunction{function: :tap} ->
              {taps, remaining} = collect_consecutive_taps([step | rest])
              last_tap = List.last(taps)
              optimize_taps(remaining, [last_tap | acc])

            other_step ->
              optimize_taps(rest, [other_step | acc])
          end
        end

        defp collect_consecutive_taps(steps) do
          Enum.split_while(steps, &match?(%Step.EitherFunction{function: :tap}, &1))
        end
      end

  ## Built-in Transformers

  Funx provides example transformers you can use:

  - `Funx.Monad.Either.Dsl.Transformers.OptimizeConsecutiveTaps` - Removes redundant
    consecutive `tap` operations, keeping only the last one. Useful for cleaning up
    debugging code or reducing side effects in pipelines.

  Transformers are opt-in - you must explicitly include them in the `:transformers` option.

  ## Usage

  Transformers are applied automatically during pipeline compilation.
  They can be configured via the `:transformers` option:

      either input, transformers: [MyTransformer] do
        bind SomeModule
      end
  """

  alias Funx.Monad.Either.Dsl.Step

  @type steps :: list(Step.t())
  @type opts :: keyword()
  @type error :: {:error, String.t() | Exception.t()}

  @doc """
  Transform a list of Step structs.

  Receives the parsed steps and any user options, and returns either:
  - `{:ok, transformed_steps}` - Modified steps
  - `{:error, message}` - Validation error (raises CompileError)

  The transformer can:
  - Optimize steps (remove redundant operations)
  - Validate cross-step constraints
  - Add implicit steps
  - Rewrite patterns into more efficient forms
  """
  @callback transform(steps(), opts()) :: {:ok, steps()} | error()

  @doc """
  Apply a list of transformers to steps in order.

  Returns `{:ok, steps}` if all transformers succeed, or the first error.
  """
  @spec apply_transformers(steps(), list(module()), opts()) :: {:ok, steps()} | error()
  def apply_transformers(steps, transformers, opts \\ []) do
    Enum.reduce_while(transformers, {:ok, steps}, fn transformer, {:ok, current_steps} ->
      case transformer.transform(current_steps, opts) do
        {:ok, new_steps} -> {:cont, {:ok, new_steps}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
