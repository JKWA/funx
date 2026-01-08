defmodule Funx.Validate.DSL.DSLTest do
  @moduledoc """
  Tests for the Validation DSL core semantics.

  ## Resolved Semantics (locked down by these tests):

  1. **`at :key` lowers to Prism by default**
     - Missing key → Nothing → most validators skip
     - Use explicit `Lens.key(:key)` for structural requirement (raises KeyError)

  2. **Required is the sole mechanism for presence validation**
     - Required must handle Nothing (from Prism)
     - Required fails on Nothing with ValidationError, not KeyError

  3. **Validation is identity on success**
     - Returns original structure unchanged
     - No `as :value` or extraction (deferred)

  4. **Empty validation is the identity element**
     - `validate do end` always returns Right(structure)
     - Law: validate(x, identity) == Right(x)

  5. **Applicative error accumulation**
     - All validators run (no short-circuiting)
     - Errors are concatenated via Appendable

  6. **Optics-first projection**
     - Lens: structural requirement (raises on missing)
     - Prism: optional (Nothing skips validators except Required)
     - Traversal: relates fixed foci (not iteration)
  """
  use ExUnit.Case, async: true

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Optics.{Lens, Prism}
  alias Funx.Validator.{Email, MinLength, Positive, Required}

  # Custom validator for date range validation (not a built-in)
  defmodule DateRange do
    @behaviour Funx.Validate.Behaviour
    alias Funx.Monad.Maybe.Nothing

    def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

    @impl true
    def validate(value, opts, env)
    def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

    def validate([start_date, end_date], _opts, _env) do
      if Date.compare(start_date, end_date) == :lt do
        Either.right([start_date, end_date])
      else
        Either.left(ValidationError.new("start_date must be before end_date"))
      end
    end
  end

  describe "root validators (no `at`)" do
    defmodule HasContactMethod do
      @behaviour Funx.Validate.Behaviour

      def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

      @impl true
      def validate(value, opts, env)

      def validate(%{email: email} = value, _opts, _env) when is_binary(email),
        do: Either.right(value)

      def validate(%{phone: phone} = value, _opts, _env) when is_binary(phone),
        do: Either.right(value)

      def validate(_, _opts, _env),
        do: Either.left(ValidationError.new("must have a contact method"))
    end

    defmodule ValidTimezone do
      @behaviour Funx.Validate.Behaviour

      def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

      @impl true
      def validate(value, opts, env)

      def validate(%{timezone: tz} = value, _opts, _env) when tz in ["UTC", "PST", "EST"],
        do: Either.right(value)

      def validate(%{timezone: _}, _opts, _env),
        do: Either.left(ValidationError.new("invalid timezone"))

      def validate(value, _opts, _env),
        do: Either.right(value)
    end

    test "runs a single root validator against the entire structure" do
      use Funx.Validate

      validation =
        validate do
          HasContactMethod
        end

      result = Either.validate(%{email: "alice@example.com"}, validation)

      assert %Right{} = result
    end

    test "root validator can fail validation" do
      use Funx.Validate

      validation =
        validate do
          HasContactMethod
        end

      result = Either.validate(%{name: "Alice"}, validation)

      assert %Left{left: %ValidationError{errors: ["must have a contact method"]}} =
               result
    end

    test "multiple root validators run applicatively" do
      use Funx.Validate

      validation =
        validate do
          HasContactMethod
          ValidTimezone
        end

      result =
        Either.validate(
          %{name: "Alice", timezone: "Mars"},
          validation
        )

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "must have a contact method" in errors
      assert "invalid timezone" in errors
      assert length(errors) == 2
    end

    test "root validators compose with `at` clauses" do
      use Funx.Validate

      validation =
        validate do
          HasContactMethod
          at :age, Positive
        end

      result =
        Either.validate(
          %{email: "alice@example.com", age: 30},
          validation
        )

      assert %Right{} = result
    end

    test "root validator failures accumulate with projected failures" do
      use Funx.Validate

      validation =
        validate do
          HasContactMethod
          at :age, Positive
        end

      result =
        Either.validate(
          %{age: -1},
          validation
        )

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "must have a contact method" in errors
      assert "must be positive" in errors
      assert length(errors) == 2
    end

    test "root validators preserve identity on success" do
      use Funx.Validate

      input = %{email: "alice@example.com", timezone: "UTC"}

      validation =
        validate do
          HasContactMethod
          ValidTimezone
        end

      result = Either.validate(input, validation)

      assert %Right{right: ^input} = result
    end

    test "root validators receive env" do
      defmodule EnvAware do
        @behaviour Funx.Validate.Behaviour

        def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

        @impl true
        def validate(value, _opts, env) do
          if env[:ok?] do
            Either.right(value)
          else
            Either.left(ValidationError.new("env rejected"))
          end
        end
      end

      use Funx.Validate

      validation =
        validate do
          EnvAware
        end

      assert %Right{} =
               Either.validate(%{}, validation, env: %{ok?: true})

      assert %Left{left: %ValidationError{errors: ["env rejected"]}} =
               Either.validate(%{}, validation, env: %{ok?: false})
    end
  end

  describe "top-level predicate validators (lift_predicate)" do
    defmodule HasMinimumFields do
      @behaviour Funx.Validate.Behaviour

      def validate(data, opts) when is_list(opts), do: validate(data, opts, %{})

      @impl true
      def validate(data, _opts, _env) do
        Either.lift_predicate(
          data,
          fn d -> map_size(d) >= 2 end,
          fn d -> ValidationError.new("expected at least 2 fields, got #{map_size(d)}") end
        )
      end
    end

    test "passes and returns original structure on success" do
      use Funx.Validate

      validation_def =
        validate do
          HasMinimumFields
        end

      data = %{a: 1, b: 2}

      result = Either.validate(data, validation_def)

      # Identity preserved
      assert result == %Right{right: data}
    end

    test "fails with contextual error derived from value" do
      use Funx.Validate

      validation_def =
        validate do
          HasMinimumFields
        end

      data = %{a: 1}

      result = Either.validate(data, validation_def)

      assert %Left{left: %ValidationError{errors: ["expected at least 2 fields, got 1"]}} =
               result
    end
  end

  describe "top-level Maybe validators (lift_maybe)" do
    defmodule RequiresTimezone do
      @behaviour Funx.Validate.Behaviour

      def validate(data, opts) when is_list(opts), do: validate(data, opts, %{})

      @impl true
      def validate(data, _opts, _env) do
        case Map.get(data, :timezone) do
          nil ->
            Either.left(ValidationError.new("timezone missing for user #{inspect(data)}"))

          _ ->
            Either.right(data)
        end
      end
    end

    test "passes when Maybe is Just and returns original structure" do
      use Funx.Validate

      validation_def =
        validate do
          RequiresTimezone
        end

      data = %{email: "alice@example.com", timezone: "UTC"}

      result = Either.validate(data, validation_def)

      assert result == %Right{right: data}
    end

    test "fails with contextual error when Maybe is Nothing" do
      use Funx.Validate

      validation_def =
        validate do
          RequiresTimezone
        end

      data = %{email: "alice@example.com"}

      result = Either.validate(data, validation_def)

      assert %Left{left: %ValidationError{errors: [error]}} = result
      assert String.contains?(error, "timezone missing")
      assert String.contains?(error, "alice@example.com")
    end
  end

  describe "contextual errors accumulate applicatively" do
    test "multiple lifted validators contribute independent contextual errors" do
      use Funx.Validate
      alias __MODULE__.{HasMinimumFields, RequiresTimezone}

      validation_def =
        validate do
          HasMinimumFields
          RequiresTimezone
        end

      data = %{a: 1}

      result = Either.validate(data, validation_def)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 2
      assert Enum.any?(errors, &String.contains?(&1, "expected at least 2 fields"))
      assert Enum.any?(errors, &String.contains?(&1, "timezone missing"))
    end
  end

  describe "basic at with Prism (at :key lowers to Prism by default)" do
    test "validates present field successfully" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "fails when required field is missing (Required sees Nothing)" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
        end

      # at :name lowers to Prism.key(:name)
      # Missing key → Nothing → Required runs on Nothing → ValidationError
      result = Either.validate(%{age: 30}, user_validation)

      assert %Left{left: %ValidationError{errors: ["is required"]}} = result
    end

    test "validates with validator returning error on empty value" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
        end

      result = Either.validate(%{name: ""}, user_validation)

      assert %Left{left: %ValidationError{errors: ["is required"]}} = result
    end

    test "validates multiple fields independently" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
          at :email, Required
        end

      result = Either.validate(%{name: "Alice", email: "alice@example.com"}, user_validation)

      assert result == %Right{right: %{name: "Alice", email: "alice@example.com"}}
    end

    test "accumulates all errors from multiple fields" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
          at :email, Required
        end

      result = Either.validate(%{name: "", email: ""}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "is required" in errors
      assert length(errors) == 2
    end
  end

  describe "explicit Lens (for required structural fields)" do
    test "validates present field successfully" do
      use Funx.Validate

      user_validation =
        validate do
          at Lens.key(:name), Required
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "raises KeyError when required field is structurally missing" do
      use Funx.Validate

      user_validation =
        validate do
          at Lens.key(:name), Required
        end

      # Explicit Lens requires the key to exist structurally
      assert_raise KeyError, fn ->
        Either.validate(%{age: 30}, user_validation)
      end
    end
  end

  describe "at with Prism (optional fields)" do
    test "passes validation when optional field is missing (using Positive)" do
      use Funx.Validate

      user_validation =
        validate do
          at Prism.key(:age), Positive
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "validates when optional field is present and valid" do
      use Funx.Validate

      user_validation =
        validate do
          at Prism.key(:age), Positive
        end

      result = Either.validate(%{age: 25}, user_validation)

      assert result == %Right{right: %{age: 25}}
    end

    test "fails when optional field is present but invalid" do
      use Funx.Validate

      user_validation =
        validate do
          at Prism.key(:age), Positive
        end

      result = Either.validate(%{age: -5}, user_validation)

      assert %Left{left: %ValidationError{errors: ["must be positive"]}} = result
    end
  end

  describe "projection applicability (critical semantic)" do
    test "at :key with non-Required validator on missing key" do
      use Funx.Validate

      user_validation =
        validate do
          at :age, Positive
        end

      # Positive validator skips Nothing from missing key
      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "at :key with Required fails when key is missing" do
      use Funx.Validate

      user_validation =
        validate do
          at :email, [Required, Email]
        end

      # at :email lowers to Prism.key(:email)
      # Missing key → Nothing → Required runs on Nothing → ValidationError
      # Email also runs on Nothing and may produce additional errors
      result = Either.validate(%{name: "Alice"}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "is required" in errors
    end

    test "at :key with Required validates when present" do
      use Funx.Validate

      user_validation =
        validate do
          at :email, [Required, Email]
        end

      # Both Required and Email run on the value
      result = Either.validate(%{email: "alice@example.com"}, user_validation)

      assert %Right{} = result
    end

    test "at :key with Required accumulates errors from both validators" do
      use Funx.Validate

      user_validation =
        validate do
          at :email, [Required, Email]
        end

      # Empty string fails both Required and Email
      result = Either.validate(%{email: ""}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) == 2
      assert "is required" in errors
      assert "must be a valid email" in errors
    end
  end

  describe "validator options" do
    test "passes options to validator using tuple syntax" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, {MinLength, min: 3}
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "fails when validator with options doesn't pass" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, {MinLength, min: 10}
        end

      result = Either.validate(%{name: "Bob"}, user_validation)

      assert %Left{left: %ValidationError{errors: ["must be at least 10 characters"]}} = result
    end

    test "combines multiple validators with options" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, [Required, {MinLength, min: 3}]
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "accumulates errors from multiple validators" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, [Required, {MinLength, min: 3}]
        end

      result = Either.validate(%{name: ""}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "is required" in errors
      assert length(errors) == 2
    end
  end

  describe "Lens composition (nested paths)" do
    test "validates nested field using Lens.compose" do
      use Funx.Validate

      user_validation =
        validate do
          at Lens.compose([Lens.key(:user), Lens.key(:name)]), Required
        end

      result = Either.validate(%{user: %{name: "Alice"}}, user_validation)

      assert result == %Right{right: %{user: %{name: "Alice"}}}
    end

    test "fails when nested field is invalid" do
      use Funx.Validate

      user_validation =
        validate do
          at Lens.compose([Lens.key(:user), Lens.key(:name)]), Required
        end

      result = Either.validate(%{user: %{name: ""}}, user_validation)

      assert %Left{left: %ValidationError{errors: ["is required"]}} = result
    end
  end

  describe "projection types" do
    test "atom projections are normalized to Prism by parser" do
      use Funx.Validate

      # Atom :email is normalized to Prism.key(:email) by the parser
      user_validation =
        validate do
          at :email, Required
        end

      # Works like Prism.key(:email) - optional field
      result = Either.validate(%{name: "Alice"}, user_validation)
      assert %Left{left: %ValidationError{errors: ["is required"]}} = result

      result = Either.validate(%{email: "alice@example.com"}, user_validation)
      assert result == %Right{right: %{email: "alice@example.com"}}
    end

    test "plain function projections are supported" do
      use Funx.Validate

      # Plain functions can be used as projections
      email_getter = fn data -> Map.get(data, :email) end

      user_validation =
        validate do
          at email_getter, Required
        end

      # Function projection extracts the value
      result = Either.validate(%{email: "alice@example.com"}, user_validation)
      assert result == %Right{right: %{email: "alice@example.com"}}

      # Function returns nil for missing key - Required should fail
      result = Either.validate(%{name: "Alice"}, user_validation)
      assert %Left{left: %ValidationError{errors: ["is required"]}} = result
    end
  end

  describe "Traversal for relating foci" do
    test "validates relationship between two fields" do
      use Funx.Validate
      alias Funx.Optics.Traversal

      booking_validation =
        validate do
          at Traversal.combine([Lens.key(:start_date), Lens.key(:end_date)]), DateRange
        end

      start_date = ~D[2024-01-01]
      end_date = ~D[2024-01-31]

      result =
        Either.validate(%{start_date: start_date, end_date: end_date}, booking_validation)

      assert result == %Right{right: %{start_date: start_date, end_date: end_date}}
    end

    test "fails when relationship validation fails" do
      use Funx.Validate
      alias Funx.Optics.Traversal

      booking_validation =
        validate do
          at Traversal.combine([Lens.key(:start_date), Lens.key(:end_date)]), DateRange
        end

      start_date = ~D[2024-01-31]
      end_date = ~D[2024-01-01]

      result =
        Either.validate(%{start_date: start_date, end_date: end_date}, booking_validation)

      assert %Left{left: %ValidationError{errors: ["start_date must be before end_date"]}} =
               result
    end
  end

  describe "environment passing" do
    defmodule UniqueEmail do
      @behaviour Funx.Validate.Behaviour
      alias Funx.Monad.Maybe.Nothing

      def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

      @impl true
      def validate(value, opts, env)
      def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

      def validate(email, _opts, env) do
        existing_emails = Map.get(env, :existing_emails, [])

        if email in existing_emails do
          Either.left(ValidationError.new("email already taken"))
        else
          Either.right(email)
        end
      end
    end

    test "passes environment to validators" do
      use Funx.Validate

      user_validation =
        validate do
          at :email, UniqueEmail
        end

      env = %{existing_emails: ["alice@example.com", "bob@example.com"]}

      result = Either.validate(%{email: "charlie@example.com"}, user_validation, env: env)

      assert result == %Right{right: %{email: "charlie@example.com"}}
    end

    test "validator can fail based on environment" do
      use Funx.Validate

      user_validation =
        validate do
          at :email, UniqueEmail
        end

      env = %{existing_emails: ["alice@example.com", "bob@example.com"]}

      result = Either.validate(%{email: "alice@example.com"}, user_validation, env: env)

      assert %Left{left: %ValidationError{errors: ["email already taken"]}} = result
    end
  end

  describe "tagged tuple return pattern" do
    defmodule LegacyValidator do
      @behaviour Funx.Validate.Behaviour

      def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

      @impl true
      def validate(value, _opts, _env) do
        if value > 0 do
          :ok
        else
          {:error, ValidationError.new("must be positive")}
        end
      end
    end

    test "normalizes :ok return" do
      use Funx.Validate

      validation_def =
        validate do
          at :score, LegacyValidator
        end

      result = Either.validate(%{score: 100}, validation_def)

      assert result == %Right{right: %{score: 100}}
    end

    test "normalizes {:error, ValidationError.t()} return" do
      use Funx.Validate

      validation_def =
        validate do
          at :score, LegacyValidator
        end

      result = Either.validate(%{score: -1}, validation_def)

      assert %Left{left: %ValidationError{errors: ["must be positive"]}} = result
    end
  end

  describe "complex validation scenarios" do
    test "validates multiple fields with multiple validators each" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
          at :age, Positive
        end

      result =
        Either.validate(
          %{name: "Alice", email: "alice@example.com", age: 30},
          user_validation
        )

      assert %Right{} = result
    end

    test "accumulates all errors from complex validation" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
          at :age, Positive
        end

      result = Either.validate(%{name: "", email: "bad", age: -5}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert length(errors) >= 3
      assert Enum.any?(errors, &String.contains?(&1, "required"))
      assert Enum.any?(errors, &String.contains?(&1, "email"))
      assert Enum.any?(errors, &String.contains?(&1, "positive"))
    end

    test "mixes Lens and Prism projections" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
          at Prism.key(:age), Positive
        end

      # Should pass even without age (Prism makes it optional, Positive skips Nothing)
      result = Either.validate(%{name: "Alice"}, user_validation)

      assert %Right{} = result
    end
  end

  describe "return value semantics" do
    test "returns original structure by default (identity on success)" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
        end

      result = Either.validate(%{name: "Alice", extra: "field"}, user_validation)

      # Validation is identity on success: returns original structure unchanged
      assert result == %Right{right: %{name: "Alice", extra: "field"}}
    end
  end

  describe "identity validation (empty validation)" do
    test "empty validation is identity (returns Right with original structure)" do
      use Funx.Validate

      # Empty validation is the identity element for validation composition
      # It always succeeds and returns the structure unchanged
      empty_validation =
        validate do
        end

      result = Either.validate(%{name: "Alice", age: 30}, empty_validation)

      assert result == %Right{right: %{name: "Alice", age: 30}}
    end

    test "empty validation succeeds on empty structure" do
      use Funx.Validate

      empty_validation =
        validate do
        end

      result = Either.validate(%{}, empty_validation)

      assert result == %Right{right: %{}}
    end
  end

  describe "parallel mode validation" do
    test "root validators run in parallel mode" do
      use Funx.Validate
      alias __MODULE__.{HasContactMethod, ValidTimezone}

      validation_def =
        validate mode: :parallel do
          HasContactMethod
          ValidTimezone
        end

      result = Either.validate(%{name: "Alice", timezone: "Mars"}, validation_def)

      assert %Left{left: %ValidationError{errors: errors}} = result
      assert "must have a contact method" in errors
      assert "invalid timezone" in errors
      assert length(errors) == 2
    end

    test "validates all fields in parallel and accumulates errors" do
      use Funx.Validate

      user_validation =
        validate mode: :parallel do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
          at :age, Positive
        end

      result = Either.validate(%{name: "", email: "bad", age: -5}, user_validation)

      assert %Left{left: %ValidationError{errors: errors}} = result
      # All validations run in parallel, all errors collected
      assert length(errors) >= 3
      assert Enum.any?(errors, &String.contains?(&1, "required"))
      assert Enum.any?(errors, &String.contains?(&1, "email"))
      assert Enum.any?(errors, &String.contains?(&1, "positive"))
    end

    test "parallel mode succeeds when all validations pass" do
      use Funx.Validate

      user_validation =
        validate mode: :parallel do
          at :name, [Required, {MinLength, min: 3}]
          at :email, [Required, Email]
          at :age, Positive
        end

      result =
        Either.validate(
          %{name: "Alice", email: "alice@example.com", age: 30},
          user_validation
        )

      assert %Right{right: %{name: "Alice", email: "alice@example.com", age: 30}} = result
    end

    test "parallel mode returns original structure on success" do
      use Funx.Validate

      input = %{name: "Alice", email: "alice@example.com", age: 30, extra: "field"}

      user_validation =
        validate mode: :parallel do
          at :name, Required
          at :email, Email
        end

      result = Either.validate(input, user_validation)

      assert %Right{right: ^input} = result
    end
  end

  describe "executor default parameter" do
    test "execute_steps/1 defaults to sequential mode" do
      alias Funx.Validate.Dsl.Executor
      alias Funx.Validate.Dsl.Step

      # Create a simple step
      steps = [%Step{optic: nil, validators: [Required]}]

      # Call execute_steps/1 without specifying mode (uses default :sequential)
      quoted_fn = Executor.execute_steps(steps)

      # Verify it returns quoted code
      assert match?({:__block__, _, _}, quoted_fn) or match?({:fn, _, _}, quoted_fn)

      # Evaluate the quoted function
      {validator_fn, _} = Code.eval_quoted(quoted_fn)

      # Verify it behaves like sequential mode
      assert is_function(validator_fn, 2)
      result = validator_fn.("value", [])
      assert %Right{} = result
    end
  end

  describe "return type options (as:)" do
    test "raises CompileError for invalid return type option" do
      assert_raise CompileError,
                   ~r/Invalid return type.*Must be :either, :tuple, or :raise/,
                   fn ->
                     Code.eval_quoted(
                       quote do
                         require Funx.Validate
                         import Funx.Validate

                         validate as: :invalid_type do
                           at :name, Required
                         end
                       end,
                       [],
                       __ENV__
                     )
                   end
    end

    test "default is :either" do
      use Funx.Validate

      user_validation =
        validate do
          at :name, Required
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "as: :either (explicit)" do
      use Funx.Validate

      user_validation =
        validate as: :either do
          at :name, Required
        end

      result = Either.validate(%{name: "Alice"}, user_validation)

      assert result == %Right{right: %{name: "Alice"}}
    end

    test "as: :tuple - success case" do
      use Funx.Validate

      user_validation =
        validate as: :tuple do
          at :name, Required
          at :email, Email
        end

      result = user_validation.(%{name: "Alice", email: "alice@example.com"}, [])

      assert result == {:ok, %{name: "Alice", email: "alice@example.com"}}
    end

    test "as: :tuple - failure case" do
      use Funx.Validate

      user_validation =
        validate as: :tuple do
          at :name, Required
          at :email, Email
        end

      result = user_validation.(%{name: "", email: "bad"}, [])

      assert {:error, %ValidationError{errors: errors}} = result
      assert "is required" in errors
      assert "must be a valid email" in errors
    end

    test "as: :raise - success case" do
      use Funx.Validate

      user_validation =
        validate as: :raise do
          at :name, Required
        end

      result = user_validation.(%{name: "Alice"}, [])

      assert result == %{name: "Alice"}
    end

    test "as: :raise - failure case" do
      use Funx.Validate

      user_validation =
        validate as: :raise do
          at :name, Required
        end

      assert_raise ValidationError, fn ->
        user_validation.(%{name: ""}, [])
      end
    end

    test "as: :tuple works with parallel mode" do
      use Funx.Validate

      user_validation =
        validate mode: :parallel, as: :tuple do
          at :name, Required
          at :email, Email
        end

      success = user_validation.(%{name: "Alice", email: "alice@example.com"}, [])
      assert success == {:ok, %{name: "Alice", email: "alice@example.com"}}

      failure = user_validation.(%{name: "", email: "bad"}, [])
      assert {:error, %ValidationError{errors: errors}} = failure
      assert "is required" in errors
      assert "must be a valid email" in errors
    end

    test "as: :raise works with parallel mode" do
      use Funx.Validate

      user_validation =
        validate mode: :parallel, as: :raise do
          at :name, Required
        end

      result = user_validation.(%{name: "Alice"}, [])
      assert result == %{name: "Alice"}

      assert_raise ValidationError, fn ->
        user_validation.(%{name: ""}, [])
      end
    end
  end
end
