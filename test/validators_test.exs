defmodule Funx.Validator.ExamplesTest do
  @moduledoc """
  Example validators demonstrating validator patterns.

  Individual validator tests are in test/validator/*.exs files.

  ## Validator Design Principles

  ## What These Tests Establish

  ### 1. Validators are Small, Total, Single-Purpose Functions

  Every built-in validator:
  - Checks exactly one condition
  - Returns input unchanged OR transformed value
  - Reports exactly one error per failure
  - No hidden control-flow semantics

  All composition semantics live in the DSL and runner, not validators.

  ### 2. Required is Semantically Special

  **CRITICAL RULE** (enforced by tests):

  > **Required is the ONLY validator that fails on absence.**

  Required fails on:
  - `nil`
  - `""`
  - `Maybe.Nothing` (from Prism projections)

  All other validators assume presence.

  ### 3. Optionality and Presence are Orthogonal

  Division of responsibility:
  - **Optics** decide whether a value is present
  - **Validators** decide what to do with a value
  - **Required** bridges the two

  **Result**: Absence is not an error unless explicitly requested.

  ### 4. Validators are Strict About Configuration

  Validators intentionally **raise** on missing required options:
  - MinLength requires `:min`
  - MaxLength requires `:max`
  - Pattern requires `:regex`
  - In requires `:values`
  - Confirmation requires `:field` and `:data`

  **Why**: These are programmer errors, not validation errors.

  Raising is correct behavior. Treating them as ValidationErrors would blur the contract boundary.

  ### 5. Error Messages are Simple, Composable, Overridable

  All validators:
  - Provide consistent default messages
  - Support custom message via `:message` option
  - Never inject structure into errors

  **Aligns with**: Flat error model (no structured errors in core).

  ### 6. Numeric Validators are Cleanly Partitioned

  Clean taxonomy with no overlap:
  - **Positive**: strictly `> 0`
  - **Negative**: strictly `< 0`
  - **Integer**: type check only
  - **Range**: inclusive bounds, flexible min/max

  Each does exactly one thing. Predictable and composable.

  ### 7. Transformation Validators are Explicitly Allowed

  Validators may transform values:
  - `TrimAndLowercase` transforms string
  - Transformations visible to downstream validators
  - Transformation does NOT affect structure

  **Confirms**: Validation is not just checking—it can normalize data.

  ### 8. Return-Type Normalization is Complete

  Full support for:
  - `Either.right / Either.left` (canonical)
  - `:ok` (legacy)
  - `{:ok, value}` (legacy with transformation)
  - `{:error, ValidationError.t()}` (legacy)

  **Result**: Legacy validators supported, migration paths clean.

  ### 9. No Cross-Cutting Concerns

  These tests do NOT introduce:
  - ❌ Cross-field logic (use Traversal)
  - ❌ Boolean composition (use predicates)
  - ❌ Execution semantics (use runners)
  - ❌ Error structure (use adapters)

  **Clean separation of concerns.**

  ## Validator Contract (Reinforced)

  ```elixir
  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
    Right.t(any())
    | Left.t(ValidationError.t())
    | :ok
    | {:ok, any()}
    | {:error, ValidationError.t()}
  ```

  ### Validator Responsibilities

  - ✅ Check single condition
  - ✅ Optionally transform value
  - ✅ Return Either or tagged tuple
  - ✅ Use ValidationError for failures
  - ✅ Raise on configuration errors (not validation errors)
  - ✅ Handle `Nothing` ONLY if you are `Required`

  ### Validator Anti-Patterns

  - ❌ Don't check multiple unrelated conditions
  - ❌ Don't implement cross-field logic
  - ❌ Don't raise for validation failures
  - ❌ Don't return raw strings as errors
  - ❌ Don't mutate env
  - ❌ Don't assume presence (unless you are Required)

  ## Built-In Validators (Fully Specified)

  | Validator | Purpose | Required Options | Optional |
  |-----------|---------|------------------|----------|
  | Required | Presence check | - | message |
  | MinLength | String length ≥ min | min | message |
  | MaxLength | String length ≤ max | max | message |
  | Email | Email format | - | message |
  | Pattern | Regex match | regex | message |
  | Range | Number in bounds | min/max | message |
  | In | Membership | values | message |
  | Positive | Number > 0 | - | message |
  | Negative | Number < 0 | - | message |
  | Integer | Type check | - | message |
  | Confirmation | Field equality | field, data | message |

  All contracts are sharp and non-overlapping.

  ## Key Design Rule (Repeat for Emphasis)

  **Required is the only validator that fails on absence.**

  This single rule explains most user-visible behavior.

  If a field is missing:
  - Prism projection → Nothing
  - Required sees Nothing → fails
  - Other validators skip Nothing → pass

  This makes fields optional-by-default with explicit presence checks.
  """
  use ExUnit.Case, async: true

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}

  describe "Custom validator with tagged tuple returns" do
    defmodule CustomValidator do
      @behaviour Funx.Validation.Behaviour

      # Convenience overload for default opts
      def validate(value) do
        validate(value, [])
      end

      # Convenience overload for easier direct usage
      def validate(value, opts) when is_list(opts) do
        validate(value, opts, %{})
      end

      @impl true
      def validate(value, opts, _env) do
        mode = Keyword.get(opts, :mode, :either)

        case mode do
          :either ->
            if value == "good" do
              Either.right(value)
            else
              Either.left(ValidationError.new("not good"))
            end

          :ok ->
            if value == "good" do
              :ok
            else
              {:error, ValidationError.new("not good")}
            end

          :ok_tuple ->
            if value == "good" do
              {:ok, value}
            else
              {:error, ValidationError.new("not good")}
            end
        end
      end
    end

    test "supports Either return pattern" do
      assert CustomValidator.validate("good", mode: :either) == %Right{right: "good"}

      assert %Left{left: %ValidationError{errors: ["not good"]}} =
               CustomValidator.validate("bad", mode: :either)
    end

    test "supports :ok return pattern" do
      assert CustomValidator.validate("good", mode: :ok) == :ok

      assert {:error, %ValidationError{errors: ["not good"]}} =
               CustomValidator.validate("bad", mode: :ok)
    end

    test "supports {:ok, value} return pattern" do
      assert CustomValidator.validate("good", mode: :ok_tuple) == {:ok, "good"}

      assert {:error, %ValidationError{errors: ["not good"]}} =
               CustomValidator.validate("bad", mode: :ok_tuple)
    end
  end

  describe "validators with transformation" do
    defmodule TrimAndLowercase do
      @behaviour Funx.Validation.Behaviour

      # Convenience overload for default opts
      def validate(value) do
        validate(value, [])
      end

      # Convenience overload for easier direct usage
      def validate(value, opts) when is_list(opts) do
        validate(value, opts, %{})
      end

      @impl true
      def validate(value, _opts, _env) when is_binary(value) do
        transformed = value |> String.trim() |> String.downcase()
        Either.right(transformed)
      end
    end

    test "returns transformed value on success" do
      assert TrimAndLowercase.validate("  HELLO  ") == %Right{right: "hello"}
    end
  end
end
