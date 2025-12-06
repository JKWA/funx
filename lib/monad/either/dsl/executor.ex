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

  defp execute_step(
         either_value,
         %Step.Bind{operation: operation, opts: opts, __meta__: meta},
         user_env
       ) do
    Funx.Monad.bind(either_value, fn value ->
      result = call_operation(operation, value, opts, user_env)
      normalize_run_result(result, meta, "bind")
    end)
  end

  defp execute_step(either_value, %Step.Map{operation: operation, opts: opts}, user_env) do
    Funx.Monad.map(either_value, fn value ->
      call_operation(operation, value, opts, user_env)
    end)
  end

  defp execute_step(either_value, %Step.Ap{applicative: applicative}, _user_env) do
    Funx.Monad.ap(either_value, applicative)
  end

  defp execute_step(
         either_value,
         %Step.EitherFunction{function: func_name, args: args},
         _user_env
       ) do
    apply(Either, func_name, [either_value | args])
  end

  defp execute_step(
         either_value,
         %Step.BindableFunction{function: func_name, args: args},
         _user_env
       ) do
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
  @spec normalize_run_result(tuple() | Either.t(any(), any()), map() | nil) ::
          Either.t(any(), any())
  @spec normalize_run_result(
          tuple() | Either.t(any(), any()),
          map() | nil,
          String.t() | nil
        ) ::
          Either.t(any(), any())
  def normalize_run_result(result, meta \\ nil, operation_type \\ nil) do
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
        location = format_location(meta)
        op_info = if operation_type, do: " in #{operation_type} operation", else: ""

        raise ArgumentError, """
        Module run/3 callback must return either an Either struct or a result tuple#{op_info}.#{location}
        Got: #{inspect(other)}

        Expected return types:
          - Either: right(value) or left(error)
          - Result tuple: {:ok, value} or {:error, reason}
        """
    end
  end

  # ============================================================================
  # METADATA FORMATTING
  # ============================================================================

  defp format_location(nil), do: ""

  defp format_location(%{line: line, column: column})
       when not is_nil(line) and not is_nil(column) do
    "\n  at line #{line}, column #{column}"
  end

  defp format_location(%{line: line}) when not is_nil(line) do
    "\n  at line #{line}"
  end

  defp format_location(_), do: ""

  # ============================================================================
  # RESULT WRAPPING
  # ============================================================================

  @doc false
  def wrap_result(result, :either) do
    case result do
      %Either.Right{} ->
        result

      %Either.Left{} ->
        result

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
