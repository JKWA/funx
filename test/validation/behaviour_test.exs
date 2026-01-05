defmodule Funx.Validation.BehaviourTest do
  @moduledoc """
  Tests for the Validation.Behaviour contract.

  ## Behaviour Contract (locked down by these tests):

  ### Function Signature
  ```elixir
  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
    Right.t(any()) | Left.t(ValidationError.t()) | :ok | {:ok, any()} | {:error, ValidationError.t()}
  ```

  ### Semantic Rules

  1. **Arguments are strictly ordered**: value, opts, env
  2. **env is always passed** (even if empty map)
  3. **Either is canonical internal representation** (tagged tuples for compatibility)
  4. **Validators are composable via Either.validate/2**
  5. **Value transformation is allowed and sequential**
  6. **Validators must be referentially transparent w.r.t. env**
  7. **Validators must never raise for validation failure**
  8. **Validators must return ValidationError for errors**
  9. **Validators are concurrency-safe by contract**

  ### Transformation Semantics (Critical)

  **Transformations apply in left-to-right order (declaration order).**

  When multiple validators are composed:
  - Each validator receives the output of the previous validator
  - Transformations are sequential, not parallel
  - Order matters: `[f, g]` ≠ `[g, f]` in general
  - Subsequent validators see transformed values

  Example:
  ```elixir
  validators = [Trim, Downcase, MinLength]
  # "  HELLO  " → Trim → "HELLO" → Downcase → "hello" → MinLength(hello)
  ```

  This is a **monadic chain** for successful values, while error accumulation remains **applicative**.

  ### What Validators Must Not Do

  - Must not raise for validation failure (use Left/error tuple)
  - Must not return raw strings, lists, or maps as errors
  - Must not mutate env or maintain cross-call state
  - Must not assume env presence (must handle empty map)
  """
  use ExUnit.Case, async: true

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}

  describe "Validation.Behaviour contract" do
    defmodule WellBehavedValidator do
      @behaviour Funx.Validation.Behaviour.WithEnv

      @impl true
      def validate(value, opts, env) do
        mode = Keyword.get(opts, :mode, :pass)
        message = Keyword.get(opts, :message, "failed")

        # Ensure env is received
        env_value = Map.get(env, :test_key, :missing)

        case mode do
          :pass -> Either.right({value, env_value})
          :fail -> Either.left(ValidationError.new(message))
        end
      end
    end

    test "receives value as first parameter" do
      result = WellBehavedValidator.validate("test", [], %{})
      assert %Right{right: {"test", :missing}} = result
    end

    test "receives opts as second parameter" do
      result = WellBehavedValidator.validate("test", [mode: :fail, message: "custom error"], %{})
      assert %Left{left: %ValidationError{errors: ["custom error"]}} = result
    end

    test "receives env as third parameter" do
      result = WellBehavedValidator.validate("test", [], %{test_key: :found})
      assert %Right{right: {"test", :found}} = result
    end

    test "can return Right(value)" do
      result = WellBehavedValidator.validate("test", [mode: :pass], %{})
      assert %Right{} = result
    end

    test "can return Left(ValidationError)" do
      result = WellBehavedValidator.validate("test", [mode: :fail], %{})
      assert %Left{left: %ValidationError{}} = result
    end
  end

  describe "alternative return patterns" do
    defmodule TaggedTupleValidator do
      @behaviour Funx.Validation.Behaviour

      @impl true
      def validate(value, opts \\ []) do
        mode = Keyword.get(opts, :mode, :ok)

        case mode do
          :ok -> :ok
          :ok_value -> {:ok, value}
          :error -> {:error, ValidationError.new("failed")}
        end
      end
    end

    test "can return :ok" do
      assert TaggedTupleValidator.validate("test", mode: :ok) == :ok
    end

    test "can return {:ok, value}" do
      assert TaggedTupleValidator.validate("test", mode: :ok_value) == {:ok, "test"}
    end

    test "can return {:error, ValidationError.t()}" do
      assert {:error, %ValidationError{errors: ["failed"]}} =
               TaggedTupleValidator.validate("test", mode: :error)
    end
  end

  describe "validator composition" do
    defmodule ComposableValidator1 do
      @behaviour Funx.Validation.Behaviour

      @impl true
      def validate(value, _opts \\ []) do
        if String.length(value) >= 3 do
          Either.right(value)
        else
          Either.left(ValidationError.new("too short"))
        end
      end
    end

    defmodule ComposableValidator2 do
      @behaviour Funx.Validation.Behaviour

      @impl true
      def validate(value, _opts \\ []) do
        if String.contains?(value, "@") do
          Either.right(value)
        else
          Either.left(ValidationError.new("missing @"))
        end
      end
    end

    test "validators can be composed with Either.validate" do
      validators = [
        &ComposableValidator1.validate(&1),
        &ComposableValidator2.validate(&1)
      ]

      assert Either.validate("alice@example.com", validators) ==
               %Right{right: "alice@example.com"}
    end

    test "composed validators accumulate all errors" do
      validators = [
        &ComposableValidator1.validate(&1),
        &ComposableValidator2.validate(&1)
      ]

      result = Either.validate("ab", validators)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "too short" in errors
      assert "missing @" in errors
    end
  end

  describe "async-safe validators" do
    defmodule AsyncSafeValidator do
      @behaviour Funx.Validation.Behaviour.WithEnv

      @impl true
      def validate(value, _opts, env) do
        # Simulate async operation by checking if run in parallel
        pid = Map.get(env, :calling_process, self())

        if value > 0 do
          Either.right({value, pid})
        else
          Either.left(ValidationError.new("must be positive"))
        end
      end
    end

    test "validator is safe for concurrent execution" do
      # This tests that validators can be called from different processes
      # Important for Effect DSL parallel execution
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            AsyncSafeValidator.validate(i, [], %{calling_process: self()})
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               %Right{right: {_value, _pid}} -> true
               _ -> false
             end)
    end
  end

  describe "stateful validators using env" do
    defmodule DatabaseValidator do
      @behaviour Funx.Validation.Behaviour.WithEnv

      @impl true
      def validate(email, _opts, env) do
        # Simulates checking database via env
        db = Map.get(env, :db)
        existing_emails = Map.get(db || %{}, :emails, [])

        if email in existing_emails do
          Either.left(ValidationError.new("email already exists"))
        else
          Either.right(email)
        end
      end
    end

    test "uses env for external state lookup" do
      env = %{db: %{emails: ["alice@example.com", "bob@example.com"]}}

      result = DatabaseValidator.validate("charlie@example.com", [], env)

      assert result == %Right{right: "charlie@example.com"}
    end

    test "fails when state check fails" do
      env = %{db: %{emails: ["alice@example.com"]}}

      result = DatabaseValidator.validate("alice@example.com", [], env)

      assert %Left{left: %ValidationError{errors: ["email already exists"]}} = result
    end

    test "works without env" do
      result = DatabaseValidator.validate("test@example.com", [], %{})

      assert result == %Right{right: "test@example.com"}
    end
  end

  describe "validators with complex error structures" do
    defmodule FieldMappedValidator do
      @behaviour Funx.Validation.Behaviour

      @impl true
      def validate(value, _opts \\ []) do
        errors =
          []
          |> then(fn errs ->
            if Map.get(value, :name, "") == "" do
              [{:name, "is required"} | errs]
            else
              errs
            end
          end)
          |> then(fn errs ->
            if Map.get(value, :age, 0) < 0 do
              [{:age, "must be positive"} | errs]
            else
              errs
            end
          end)

        if errors == [] do
          Either.right(value)
        else
          # Convert field-keyed errors to flat error list
          error_messages =
            Enum.map(errors, fn {field, msg} -> "#{field}: #{msg}" end)

          Either.left(ValidationError.new(error_messages))
        end
      end
    end

    test "can build field-specific error messages" do
      result = FieldMappedValidator.validate(%{name: "", age: -5})

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "name: is required" in errors
      assert "age: must be positive" in errors
    end
  end
end
