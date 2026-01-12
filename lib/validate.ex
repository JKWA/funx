defmodule Funx.Validate do
  @moduledoc """
  Declarative validation DSL using optics and applicative error accumulation.

  ## Overview

  The Validation DSL provides:
  - Declarative syntax for validating nested structures
  - Projection to fields using optics (Lens, Prism, Traversal)
  - Applicative error accumulation (all validators run, all errors collected)
  - Structure preservation (returns original value on success)

  ## Usage

      use Funx.Validate

      user_validation =
        validate do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
        end

      Either.validate(%{name: "Alice", email: "alice@example.com"}, user_validation)
      #=> %Right{right: %{name: "Alice", email: "alice@example.com"}}

  ## Laws

  1. **Identity**: `validate do end` returns `Right(value)`
  2. **Structure Preservation**: Successful validation returns original structure
  3. **Applicative**: All validators run; all errors accumulate

  ## Architecture

  The DSL compiles in two phases:
  1. **Parser** - Converts DSL syntax into Step nodes
  2. **Executor** - Converts Step nodes into executable validator function
  """

  alias Funx.Validate.Dsl.{Executor, Parser}

  defmacro __using__(_opts) do
    quote do
      import Funx.Validate, only: [validate: 1, validate: 2]
    end
  end

  @doc """
  Defines a validation using the DSL.

  Returns a validator function compatible with `Either.validate/2,3`.

  ## Syntax

  ### Root Validators

      validate do
        HasContactMethod
        ValidTimezone
      end

  ### Field Validation with `at`

      validate do
        at :name, Required
        at :email, Email
      end

  By default, `at :key` uses `Prism.key(:key)` (optional field).

  ### Explicit Optics

      validate do
        # Prism: optional field
        at Prism.key(:email), Email

        # Lens: required field (raises KeyError if missing)
        at Lens.key(:name), Required
      end

  ### Validator Options

      validate do
        at :name, {MinLength, min: 3}
      end

  ### Multiple Validators per Field

      validate do
        at :name, [Required, {MinLength, min: 3}]
      end

  Validators run sequentially left-to-right.

  ### Validation Modes

      # Sequential mode (default): fail-fast, short-circuits on first error
      validate mode: :sequential do
        at :name, Required
        at :email, Email
      end

      # Parallel mode: runs all validations, accumulates all errors
      validate mode: :parallel do
        at :name, Required
        at :email, Email
      end

  ## Examples

      validate do
        at :name, Required
        at :email, [Required, Email]
        at :age, Positive
      end
  """
  defmacro validate(opts \\ [], do: block) do
    mode = Keyword.get(opts, :mode, :sequential)
    compile_validation(block, mode, __CALLER__)
  end

  defp compile_validation(block, mode, caller_env) do
    steps = Parser.parse_steps(block, caller_env)
    Executor.execute_steps(steps, mode)
  end
end
