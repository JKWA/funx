defmodule Funx.Monad.Either.Dsl.Executor do
  @moduledoc false
  # Runtime execution engine for Either DSL pipelines

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Dsl.Pipeline
  alias Funx.Monad.Either.Dsl.Step

  @doc """
  Execute a pipeline by running each step in sequence
  """
  def execute_pipeline(%Pipeline{} = pipeline) do
    # Lift input
    initial = lift_input(pipeline.input)

    # Execute each step
    result =
      Enum.reduce(pipeline.steps, initial, fn step, acc ->
        execute_step(acc, step, pipeline.user_env)
      end)

    # Wrap with return type
    wrap_result(result, pipeline.return_as)
  end

  # ============================================================================
  # INPUT LIFTING
  # ============================================================================

  @doc false
  @spec lift_input(any() | Either.t(any(), any()) | {:ok, any()} | {:error, any()}) ::
          Either.t(any(), any())
  def lift_input(input) do
    case input do
      %Either.Right{} = either -> either
      %Either.Left{} = either -> either
      {:ok, value} -> Either.right(value)
      {:error, reason} -> Either.left(reason)
      value -> Either.pure(value)
    end
  end

  # ============================================================================
  # STEP EXECUTION
  # ============================================================================

  defp execute_step(either_value, %Step{type: type} = step, user_env) do
    case type do
      :bind -> handle_bind(either_value, step, user_env)
      :map -> handle_map(either_value, step, user_env)
      :ap -> handle_ap(either_value, step)
      :either_function -> handle_either_function(either_value, step)
      :bindable_function -> handle_bindable_function(either_value, step)
    end
  end

  defp handle_bind(either_value, %Step{operation: operation, opts: opts}, user_env) do
    Funx.Monad.bind(either_value, fn value ->
      result = call_operation(operation, value, opts, user_env)
      normalize_run_result(result)
    end)
  end

  defp handle_map(either_value, %Step{operation: operation, opts: opts}, user_env) do
    Funx.Monad.map(either_value, fn value ->
      call_operation(operation, value, opts, user_env)
    end)
  end

  defp handle_ap(either_value, %Step{operation: operation}) do
    Funx.Monad.ap(either_value, operation)
  end

  defp handle_either_function(either_value, %Step{operation: {func_name, args}}) do
    apply(Either, func_name, [either_value | args])
  end

  defp handle_bindable_function(either_value, %Step{operation: {func_name, args}}) do
    Funx.Monad.bind(either_value, fn value ->
      apply(Either, func_name, [value | args])
    end)
  end

  # ============================================================================
  # OPERATION CALLING
  # ============================================================================

  defp call_operation(module, value, opts, user_env) when is_atom(module) do
    module.run(value, opts, user_env)
  end

  defp call_operation(func, value, _opts, _user_env) when is_function(func) do
    func.(value)
  end

  # ============================================================================
  # RESULT NORMALIZATION
  # ============================================================================

  @doc false
  @spec normalize_run_result(tuple() | Either.t(any(), any())) :: Either.t(any(), any())
  def normalize_run_result(result) do
    case result do
      {:ok, value} ->
        Either.right(value)

      {:error, reason} ->
        Either.left(reason)

      %Either.Right{} = either ->
        either

      %Either.Left{} = either ->
        either

      other ->
        raise ArgumentError, """
        Module run/3 callback must return either an Either struct or a result tuple.
        Got: #{inspect(other)}

        Expected return types:
          - Either: right(value) or left(error)
          - Result tuple: {:ok, value} or {:error, reason}
        """
    end
  end

  # ============================================================================
  # RESULT WRAPPING
  # ============================================================================

  @doc false
  def wrap_result(result, :either) do
    case result do
      %Either.Right{} -> result
      %Either.Left{} -> result
      other ->
        raise ArgumentError, """
        Expected Either struct when using as: :either, but got: #{inspect(other)}
        """
    end
  end

  @doc false
  def wrap_result(result, :tuple), do: Either.to_result(result)

  @doc false
  def wrap_result(result, :raise), do: Either.to_try!(result)
end
