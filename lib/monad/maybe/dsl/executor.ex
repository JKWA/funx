defmodule Funx.Monad.Maybe.Dsl.Executor do
  @moduledoc false
  # Runtime execution engine for Maybe DSL pipelines

  alias Funx.Monad.{Either, Maybe}
  alias Funx.Monad.Maybe.Dsl.{Errors, Pipeline, Step}

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
         %Step.Bind{operation: operation, opts: _opts, __meta__: meta},
         _user_env
       ) do
    Funx.Monad.bind(maybe_value, fn value ->
      result = operation.(value)
      normalize_run_result(result, meta, "bind")
    end)
  end

  defp execute_step(maybe_value, %Step.Map{operation: operation, opts: _opts}, _user_env) do
    Funx.Monad.map(maybe_value, fn value ->
      operation.(value)
    end)
  end

  defp execute_step(maybe_value, %Step.Ap{applicative: applicative}, _user_env) do
    # applicative is already a function from parser transformation
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
         %Step.ProtocolFunction{protocol: protocol, function: :guard, args: [predicate | rest]},
         _user_env
       ) do
    # guard is special: protocol expects boolean, but DSL passes predicate function
    # Evaluate predicate to get boolean, then call protocol with boolean
    Funx.Monad.bind(maybe_value, fn value ->
      bool_result = predicate.(value)
      apply(protocol, :guard, [Maybe.just(value), bool_result | rest])
    end)
  end

  defp execute_step(
         maybe_value,
         %Step.ProtocolFunction{protocol: protocol, function: func_name, args: args},
         _user_env
       ) do
    # filter, filter_map, tap - args are already transformed functions by parser
    apply(protocol, func_name, [maybe_value | args])
  end

  # ============================================================================
  # RESULT NORMALIZATION
  # ============================================================================

  @doc false
  @spec normalize_run_result(tuple() | Maybe.t(any()) | Either.t(any(), any()) | nil) ::
          Maybe.t(any())
  @spec normalize_run_result(
          tuple() | Maybe.t(any()) | Either.t(any(), any()) | nil,
          map() | nil
        ) ::
          Maybe.t(any())
  @spec normalize_run_result(
          tuple() | Maybe.t(any()) | Either.t(any(), any()) | nil,
          map() | nil,
          String.t() | nil
        ) ::
          Maybe.t(any())

  def normalize_run_result(result, meta \\ nil, operation_type \\ nil)

  def normalize_run_result({:ok, value}, _meta, _operation_type),
    do: Maybe.just(value)

  def normalize_run_result({:error, _}, _meta, _operation_type),
    do: Maybe.nothing()

  def normalize_run_result(nil, _meta, _operation_type),
    do: Maybe.nothing()

  def normalize_run_result(%Maybe.Just{} = maybe, _meta, _operation_type),
    do: maybe

  def normalize_run_result(%Maybe.Nothing{} = maybe, _meta, _operation_type),
    do: maybe

  def normalize_run_result(%Either.Right{right: value}, _meta, _operation_type),
    do: Maybe.just(value)

  def normalize_run_result(%Either.Left{}, _meta, _operation_type),
    do: Maybe.nothing()

  def normalize_run_result(other, meta, operation_type) do
    raise ArgumentError, Errors.invalid_result_error(other, meta, operation_type)
  end

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
