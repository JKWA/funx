defmodule Funx.Monad.Maybe.Dsl.Transformer do
  @moduledoc """
  Behaviour for transforming Maybe DSL pipelines after parsing.

  Transformers allow post-parse optimization and validation of the pipeline.
  They receive a list of Step structs and can modify, validate, or optimize them.

  ## Compile-Time Dependencies

  ⚠️ Transformers run at **compile time** and create compile-time dependencies.

  When you use a transformer:

      maybe user_id, transformers: [MyTransformer] do
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

      defmodule ValidateNoBareModules do
        @behaviour Funx.Monad.Maybe.Dsl.Transformer

        alias Funx.Monad.Maybe.Dsl.Step

        @impl true
        def transform(steps, _opts) do
          # Validate that no steps use bare module atoms without options
          case find_bare_module(steps) do
            nil -> {:ok, steps}
            bad_step -> {:error, "Step \#{inspect(bad_step)} should use {Module, opts} syntax"}
          end
        end

        defp find_bare_module(steps) do
          Enum.find(steps, fn
            %Step.Bind{operation: op} when is_atom(op) -> true
            %Step.Map{operation: op} when is_atom(op) -> true
            _ -> false
          end)
        end
      end

  ## Built-in Transformers

  Currently, no built-in transformers are provided. Transformers are opt-in and can
  be created for project-specific optimizations or validations.

  ## Usage

  Transformers are applied automatically during pipeline compilation.
  They can be configured via the `:transformers` option:

      maybe input, transformers: [MyTransformer] do
        bind SomeModule
      end
  """

  alias Funx.Monad.Maybe.Dsl.Step

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
