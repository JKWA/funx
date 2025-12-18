defmodule Funx.Monad.Maybe.Dsl.Executor do
  @moduledoc false
  # Runtime execution engine for Maybe DSL pipelines

  alias Funx.Monad.{Either, Maybe}
  alias Funx.Monad.Maybe.Dsl.Pipeline
  alias Funx.Monad.Maybe.Dsl.Step

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
  @spec lift_input(
          any()
          | Maybe.t(any())
          | Either.t(any(), any())
          | {:ok, any()}
          | {:error, any()}
        ) ::
          Maybe.t(any())
  def lift_input(input) do
    case input do
      %Maybe.Just{} = maybe -> maybe
      %Maybe.Nothing{} = maybe -> maybe
      %Either.Right{} = either -> Maybe.lift_either(either)
      %Either.Left{} = either -> Maybe.lift_either(either)
      {:ok, value} -> Maybe.just(value)
      {:error, _} -> Maybe.nothing()
      nil -> Maybe.nothing()
      value -> Maybe.just(value)
    end
  end

  # ============================================================================
  # STEP EXECUTION
  # ============================================================================

  defp execute_step(
         maybe_value,
         %Step.Bind{operation: operation, opts: opts, __meta__: meta},
         user_env
       ) do
    Funx.Monad.bind(maybe_value, fn value ->
      result = call_operation(operation, value, opts, user_env)
      normalize_run_result(result, meta, "bind")
    end)
  end

  defp execute_step(maybe_value, %Step.Map{operation: operation, opts: opts}, user_env) do
    Funx.Monad.map(maybe_value, fn value ->
      call_operation(operation, value, opts, user_env)
    end)
  end

  defp execute_step(maybe_value, %Step.Ap{applicative: applicative}, _user_env) do
    Funx.Monad.ap(maybe_value, applicative)
  end

  defp execute_step(
         maybe_value,
         %Step.MaybeFunction{function: func_name, args: args},
         _user_env
       ) do
    apply(Maybe, func_name, [maybe_value | args])
  end

  defp execute_step(
         maybe_value,
         %Step.ProtocolFunction{protocol: protocol, function: func_name, args: args},
         _user_env
       ) do
    apply(protocol, func_name, [maybe_value | args])
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
  @spec normalize_run_result(tuple() | Maybe.t(any()) | nil) :: Maybe.t(any())
  @spec normalize_run_result(tuple() | Maybe.t(any()) | nil, map() | nil) ::
          Maybe.t(any())
  @spec normalize_run_result(
          tuple() | Maybe.t(any()) | nil,
          map() | nil,
          String.t() | nil
        ) ::
          Maybe.t(any())
  def normalize_run_result(result, meta \\ nil, operation_type \\ nil) do
    case result do
      {:ok, value} ->
        Maybe.just(value)

      {:error, _} ->
        Maybe.nothing()

      nil ->
        Maybe.nothing()

      %Maybe.Just{} = maybe ->
        maybe

      %Maybe.Nothing{} = maybe ->
        maybe

      other ->
        location = format_location(meta)
        op_info = if operation_type, do: " in #{operation_type} operation", else: ""

        raise ArgumentError, """
        Module run/3 callback must return either a Maybe struct, a result tuple, or nil#{op_info}.#{location}
        Got: #{inspect(other)}

        Expected return types:
          - Maybe: just(value) or nothing()
          - Result tuple: {:ok, value} or {:error, reason}
          - nil (lifted to nothing())
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
  def wrap_result(result, :maybe) do
    case result do
      %Maybe.Just{} ->
        result

      %Maybe.Nothing{} ->
        result

      other ->
        raise ArgumentError, """
        Expected Maybe struct when using as: :maybe, but got: #{inspect(other)}
        """
    end
  end

  @doc false
  def wrap_result(result, :raise), do: Maybe.to_try!(result)

  @doc false
  def wrap_result(result, nil), do: Maybe.to_nil(result)
end
