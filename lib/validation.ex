defmodule Funx.Validation do
  @moduledoc """
  Declarative validation DSL using optics and applicative error accumulation.

  ## Overview

  The Validation DSL provides:
  - Declarative syntax for validating nested structures
  - Projection to fields using optics (Lens, Prism, Traversal)
  - Applicative error accumulation (all validators run, all errors collected)
  - Structure preservation (returns original value on success)

  ## Usage

      use Funx.Validation

      user_validation =
        validation do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
        end

      Either.validate(%{name: "Alice", email: "alice@example.com"}, user_validation)
      #=> %Right{right: %{name: "Alice", email: "alice@example.com"}}

  ## Laws

  1. **Identity**: `validation do end` returns `Right(value)`
  2. **Structure Preservation**: Successful validation returns original structure
  3. **Applicative**: All validators run; all errors accumulate

  ## Architecture

  The DSL compiles in two phases:
  1. **Parser** - Converts DSL syntax into Step nodes
  2. **Executor** - Converts Step nodes into executable validator function
  """

  alias Funx.Validation.Dsl.{Executor, Parser}

  defmacro __using__(_opts) do
    quote do
      import Funx.Validation, only: [validation: 1, validation: 2]
    end
  end

  @doc """
  Defines a validation using the DSL.

  Returns a validator function compatible with `Either.validate/2,3`.

  ## Syntax

  ### Root Validators

      validation do
        HasContactMethod
        ValidTimezone
      end

  ### Field Validation with `at`

      validation do
        at :name, Required
        at :email, Email
      end

  By default, `at :key` uses `Prism.key(:key)` (optional field).

  ### Explicit Optics

      validation do
        # Prism: optional field
        at Prism.key(:email), Email

        # Lens: required field (raises KeyError if missing)
        at Lens.key(:name), Required
      end

  ### Validator Options

      validation do
        at :name, {MinLength, min: 3}
      end

  ### Multiple Validators per Field

      validation do
        at :name, [Required, {MinLength, min: 3}]
      end

  Validators run sequentially left-to-right.

  ### Validation Modes

      # Sequential mode (default): fail-fast, short-circuits on first error
      validation mode: :sequential do
        at :name, Required
        at :email, Email
      end

      # Parallel mode: runs all validations, accumulates all errors
      validation mode: :parallel do
        at :name, Required
        at :email, Email
      end

  ### Return Type Options

      # Either (default): returns Either.t()
      validation as: :either do
        at :name, Required
      end

      # Tuple: returns {:ok, value} or {:error, error}
      validation as: :tuple do
        at :name, Required
      end

      # Raise: returns value or raises on error
      validation as: :raise do
        at :name, Required
      end

  ## Examples

      validation do
        at :name, Required
        at :email, [Required, Email]
        at :age, Positive
      end
  """
  defmacro validation(opts \\ [], do: block) do
    mode = Keyword.get(opts, :mode, :sequential)
    as = Keyword.get(opts, :as, :either)

    # Validate as at compile time
    unless as in [:either, :tuple, :raise] do
      raise CompileError,
        description: "Invalid return type: #{inspect(as)}. Must be :either, :tuple, or :raise"
    end

    compile_validation(block, mode, as, __CALLER__)
  end

  defp compile_validation(block, mode, as, caller_env) do
    steps = Parser.parse_steps(block, caller_env)
    Executor.execute_steps(steps, mode, as)
  end
end
