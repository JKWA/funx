defmodule Funx.Validation.Dsl.Executor do
  @moduledoc false
  # Converts Step nodes into executable validator functions.
  #
  # ## Output
  #
  # Generates a function: `(value, opts) -> Either.t()` that:
  #   - Runs all validators applicatively
  #   - Accumulates all errors
  #   - Returns Right(original_value) on success
  #   - Returns Left(ValidationError) on failure

  import Funx.Monad, only: [map: 2]

  alias Funx.Monad.Effect
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Optics.{Lens, Prism, Traversal}
  alias Funx.Validation.Dsl.Step

  @doc """
  Execute a list of Step nodes and generate a validator function.
  """
  def execute_steps(steps, mode \\ :sequential, as \\ :either)

  def execute_steps(steps, :sequential, as) do
    validator_fn =
      quote do
        validator_fns = unquote(compile_steps_to_validators(steps, :sequential))

        # Return the core validator function that always returns Either.t()
        fn value, opts ->
          Either.traverse_a(validator_fns, fn validator_fn ->
            validator_fn.(value, opts)
          end)
          |> map(fn _ -> value end)
        end
      end

    if as == :either do
      validator_fn
    else
      quote do
        core_fn = unquote(validator_fn)

        fn value, opts ->
          result = core_fn.(value, opts)
          unquote(__MODULE__).wrap_result(result, unquote(as))
        end
      end
    end
  end

  def execute_steps(steps, :parallel, as) do
    validator_fn =
      quote do
        validator_fns = unquote(compile_steps_to_validators(steps, :parallel))

        # Return the core validator function that always returns Either.t()
        fn value, opts ->
          Effect.traverse_a(validator_fns, fn effect_fn ->
            effect_fn.(value, opts)
          end)
          |> Effect.run()
          |> map(fn _ -> value end)
        end
      end

    if as == :either do
      validator_fn
    else
      quote do
        core_fn = unquote(validator_fn)

        fn value, opts ->
          result = core_fn.(value, opts)
          unquote(__MODULE__).wrap_result(result, unquote(as))
        end
      end
    end
  end

  # Compile steps into validator functions
  defp compile_steps_to_validators(steps, mode) do
    Enum.map(steps, &compile_step(&1, mode))
  end

  # Compile a single step
  defp compile_step(%Step{optic: nil, validators: validators}, mode) do
    # Root validator - no projection
    compile_root_validators(validators, mode)
  end

  defp compile_step(%Step{optic: optic, validators: validators}, mode) do
    # Projected validator - apply optic then validate
    compile_projected_validators(optic, validators, mode)
  end

  # Compile root validators (no projection)
  defp compile_root_validators(validators, :sequential) do
    validator_calls = Enum.map(validators, &compile_validator_call/1)

    quote do
      fn value, opts ->
        validators = unquote(validator_calls)
        unquote(__MODULE__).apply_validators_return(value, value, validators, opts)
      end
    end
  end

  defp compile_root_validators(validators, :parallel) do
    validator_calls = Enum.map(validators, &compile_validator_call/1)

    quote do
      fn value, opts ->
        validators = unquote(validator_calls)

        Effect.lift_either(fn ->
          unquote(__MODULE__).apply_validators_return(value, value, validators, opts)
        end)
      end
    end
  end

  # Compile projected validators (with optic)
  defp compile_projected_validators(optic, validators, :sequential) do
    validator_calls = Enum.map(validators, &compile_validator_call/1)

    quote do
      fn value, opts ->
        optic = unquote(optic)
        projected = unquote(__MODULE__).project_optic(value, optic)
        unwrapped = unquote(__MODULE__).unwrap_maybe(projected)
        validators = unquote(validator_calls)

        unquote(__MODULE__).apply_validators_return(unwrapped, value, validators, opts)
      end
    end
  end

  defp compile_projected_validators(optic, validators, :parallel) do
    validator_calls = Enum.map(validators, &compile_validator_call/1)

    quote do
      fn value, opts ->
        optic = unquote(optic)
        projected = unquote(__MODULE__).project_optic(value, optic)
        unwrapped = unquote(__MODULE__).unwrap_maybe(projected)
        validators = unquote(validator_calls)

        Effect.lift_either(fn ->
          unquote(__MODULE__).apply_validators_return(unwrapped, value, validators, opts)
        end)
      end
    end
  end

  # Project to the value using the optic (public for use in quoted code)
  @doc false
  def project_optic(value, %Lens{} = optic) do
    # Lens = structural requirement, use view! to get raw value and raise on missing
    Lens.view!(value, optic)
  end

  def project_optic(value, %Prism{} = optic) do
    # Prism = optional field, returns Maybe (atoms are converted to Prism by parser)
    Prism.preview(value, optic)
  end

  def project_optic(value, %Traversal{} = optic) do
    Traversal.to_list(value, optic)
  end

  def project_optic(value, optic) when is_function(optic, 1) do
    # Plain projection function
    optic.(value)
  end

  # Unwrap Maybe values from Prism (public for use in quoted code)
  @doc false
  def unwrap_maybe(%Nothing{} = nothing), do: nothing
  def unwrap_maybe(%Just{value: v}), do: v
  def unwrap_maybe(value), do: value

  # Apply validators applicatively (public for use in quoted code)
  @doc false
  def apply_validators(value, validators, opts) do
    Either.traverse_a(validators, fn validator_fn ->
      validator_fn.(value, opts)
    end)
  end

  # Apply validators and return a specific value on success (public for use in quoted code)
  @doc false
  def apply_validators_return(validate_value, return_value, validators, opts) do
    apply_validators(validate_value, validators, opts)
    |> map(fn _ -> return_value end)
  end

  # Compile a single validator call
  # Handles: Module, {Module, opts}
  # All validators are arity-3: validate(value, opts, env)
  defp compile_validator_call({validator_module, validator_opts}) when is_list(validator_opts) do
    quote do
      fn value, runtime_opts ->
        # Merge validator-specific opts with runtime opts
        # Runtime opts (like env) take precedence
        merged_opts = Keyword.merge(unquote(validator_opts), runtime_opts)
        env = Keyword.get(merged_opts, :env, %{})

        # All validators are arity-3: validate(value, opts, env)
        result = unquote(validator_module).validate(value, merged_opts, env)

        # Normalize validator return values to Either
        case result do
          %Right{} -> result
          %Left{} -> result
          :ok -> Either.right(value)
          {:error, error} -> Either.left(error)
        end
      end
    end
  end

  defp compile_validator_call(validator_module) do
    quote do
      fn value, opts ->
        env = Keyword.get(opts, :env, %{})

        # All validators are arity-3: validate(value, opts, env)
        result = unquote(validator_module).validate(value, opts, env)

        # Normalize validator return values to Either
        case result do
          %Right{} -> result
          %Left{} -> result
          :ok -> Either.right(value)
          {:error, error} -> Either.left(error)
        end
      end
    end
  end

  # ============================================================================
  # RETURN TYPE WRAPPING
  # ============================================================================

  @doc false
  def wrap_result(result, :tuple), do: Either.to_result(result)

  @doc false
  def wrap_result(result, :raise), do: Either.to_try!(result)
end
