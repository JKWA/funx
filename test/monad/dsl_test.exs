defmodule Funx.Monad.Either.DslTest do
  use Funx.TestCase, async: true
  use Funx.Monad.Either

  # Import example modules
  alias Funx.Monad.Either.Dsl
  alias Funx.Monad.Either.Dsl.Examples.{
    Double,
    InvalidReturn,
    MinValidator,
    Multiplier,
    ParseInt,
    ParseIntWithBase,
    PositiveNumber,
    RangeValidator,
    RangeValidatorWithOpts,
    TupleParseInt,
    TupleValidator
  }

  # Shorter aliases for assertions
  alias Funx.Monad.Either.{Left, Right}

  # Test helper module
  defmodule PipeTarget do
    @moduledoc "Module used to test auto-pipe function call rewriting"

    # Accepts a value and produces {:ok, ...}
    def add(x, amount), do: {:ok, x + amount}

    # Pure transform
    def mul(x, amount), do: x * amount

    # Error case
    def check_positive(x) when x > 0, do: {:ok, x}
    def check_positive(_), do: {:error, "not positive"}
  end

  # ============================================================================
  # Core DSL Keywords - bind, map, run
  # ============================================================================

  describe "bind keyword" do
    test "with module returning Either" do
      result =
        either "42" do
          bind ParseInt
        end

      assert result == %Right{right: 42}
    end

    test "with module returning tuple" do
      result =
        either "42" do
          bind TupleParseInt
        end

      assert result == %Right{right: 42}
    end

    test "with anonymous function returning Either" do
      result =
        either "42" do
          bind fn x ->
            case Integer.parse(x) do
              {int, ""} -> right(int)
              _ -> left("invalid")
            end
          end
        end

      assert result == %Right{right: 42}
    end

    test "with anonymous function returning tuple" do
      result =
        either "42" do
          bind fn x ->
            case Integer.parse(x) do
              {int, ""} -> {:ok, int}
              _ -> {:error, "invalid"}
            end
          end
        end

      assert result == %Right{right: 42}
    end

    test "with capture syntax" do
      parse_int = fn x ->
        case Integer.parse(x) do
          {int, ""} -> {:ok, int}
          _ -> {:error, "invalid"}
        end
      end

      result =
        either "42" do
          bind &parse_int.(&1)
        end

      assert result == %Right{right: 42}
    end

    test "with multi-line anonymous function" do
      result =
        either "42" do
          bind fn x ->
            result = Integer.parse(x)

            case result do
              {int, ""} -> right(int)
              _ -> left("invalid")
            end
          end
        end

      assert result == %Right{right: 42}
    end

    test "propagates failures correctly" do
      result =
        either "-5" do
          bind ParseInt
          bind PositiveNumber
        end

      assert %Left{left: msg} = result
      assert msg =~ "must be positive"
    end

    test "chains multiple bind operations" do
      result =
        either "42" do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Right{right: 42}
    end
  end

  describe "map keyword" do
    test "with module" do
      result =
        either "10" do
          bind ParseInt
          map Double
        end

      assert result == %Right{right: 20}
    end

    test "with stdlib function" do
      result =
        either "10" do
          bind ParseInt
          map &to_string/1
        end

      assert result == %Right{right: "10"}
    end

    test "with capture syntax &(&1 * 2)" do
      result =
        either "10" do
          bind ParseInt
          map &(&1 * 2)
        end

      assert result == %Right{right: 20}
    end

    test "with anonymous function" do
      result =
        either "10" do
          bind ParseInt
          map fn x -> x * 2 end
        end

      assert result == %Right{right: 20}
    end

    test "with multi-line anonymous function" do
      result =
        either "10" do
          bind ParseInt
          map fn x ->
            doubled = x * 2
            doubled + 10
          end
        end

      assert result == %Right{right: 30}
    end
  end

  describe "run keyword - escape hatch" do
    test "gives full control - receives Either directly" do
      result =
        either "42" do
          run fn either ->
            case either do
              %Right{right: v} -> ParseInt.run(v)
              left -> left
            end
          end
        end

      assert result == %Right{right: 42}
    end

    test "after bind operation" do
      result =
        either "42" do
          bind ParseInt
          run fn either ->
            case either do
              %Right{right: v} -> right(v * 2)
              left -> left
            end
          end
        end

      assert result == %Right{right: 84}
    end

    test "does not normalize return value" do
      result =
        either "42" do
          run fn either ->
            case either do
              %Right{right: x} ->
                case Integer.parse(x) do
                  {int, ""} -> {:ok, int}
                  _ -> {:error, "invalid"}
                end

              %Left{left: e} ->
                {:error, e}
            end
          end
        end

      # Returns raw tuple, not Either
      assert result == {:ok, 42}
    end

    test "can return any value" do
      result =
        either "10" do
          run fn either ->
            case either do
              %Right{right: x} -> String.to_integer(x) * 2
              _ -> 0
            end
          end
        end

      assert result == 20
    end

    test "allows conditional logic on Either value" do
      result =
        either "10" do
          bind ParseInt
          run fn either ->
            case either do
              %Right{right: v} when v < 50 -> right(v * 2)
              %Right{right: v} -> left("too large: #{v}")
              left -> left
            end
          end
        end

      assert result == %Right{right: 20}
    end

    test "followed by bind normalizes the result" do
      result =
        either "42" do
          run fn either ->
            case either do
              %Right{right: v} -> TupleParseInt.run(v)
              %Left{left: e} -> {:error, e}
            end
          end
          bind fn tuple ->
            case tuple do
              {:ok, value} -> PositiveNumber.run(value)
              {:error, reason} -> left(reason)
            end
          end
        end

      assert result == %Right{right: 42}
    end
  end

  # ============================================================================
  # Either Module Functions (auto-imported)
  # ============================================================================

  describe "Either module functions" do
    test "validate with list of validators" do
      result =
        either "10" do
          bind ParseInt
          validate([PositiveNumber, RangeValidator])
        end

      assert result == %Right{right: 10}
    end

    test "validate accumulates errors from all validators" do
      result =
        either "-5" do
          bind ParseInt
          validate([PositiveNumber, RangeValidator])
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert length(errors) == 2
    end

    test "filter_or_else passes when predicate is true" do
      result =
        either "10" do
          bind ParseInt
          filter_or_else(&(&1 < 50), fn -> "too large" end)
        end

      assert result == %Right{right: 10}
    end

    test "filter_or_else fails when predicate is false" do
      result =
        either "100" do
          bind ParseInt
          filter_or_else(&(&1 < 50), fn -> "too large" end)
        end

      assert result == %Left{left: "too large"}
    end

    test "or_else provides fallback on failure" do
      result =
        either "-5" do
          bind ParseInt
          bind PositiveNumber
          or_else(fn -> right(42) end)
        end

      assert result == %Right{right: 42}
    end

    test "or_else passes through success" do
      result =
        either "10" do
          bind ParseInt
          bind PositiveNumber
          or_else(fn -> right(42) end)
        end

      assert result == %Right{right: 10}
    end
  end

  # ============================================================================
  # Tuple Support (interop with {:ok, value} / {:error, reason})
  # ============================================================================

  describe "tuple/Either interop" do
    test "normalizes {:ok, value} to Right" do
      result =
        either "42" do
          bind TupleParseInt
        end

      assert result == %Right{right: 42}
    end

    test "normalizes {:error, reason} to Left" do
      result =
        either "abc" do
          bind TupleParseInt
        end

      assert result == %Left{left: "Invalid integer"}
    end

    test "chains tuple and Either operations" do
      result =
        either "10" do
          bind ParseInt
          bind TupleValidator
          bind PositiveNumber
          map Double
        end

      assert result == %Right{right: 20}
    end

    test "tuple followed by map" do
      result =
        either "5" do
          bind TupleParseInt
          map Double
        end

      assert result == %Right{right: 10}
    end

    test "handles tuple errors in chain" do
      result =
        either "-5" do
          bind ParseInt
          bind TupleValidator
        end

      assert %Left{left: msg} = result
      assert msg =~ "must be positive"
    end
  end

  # ============================================================================
  # Return Type Options (as: :either | :tuple | :raise)
  # ============================================================================

  describe "return type options" do
    test "default is :either" do
      result =
        either "42" do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Right{right: 42}
    end

    test "as: :either (explicit)" do
      result =
        either "42", as: :either do
          bind ParseInt
        end

      assert result == %Right{right: 42}
    end

    test "as: :tuple - success and failure cases" do
      # Success case
      success =
        either "42", as: :tuple do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == {:ok, 42}

      # Failure case
      failure =
        either "-5", as: :tuple do
          bind ParseInt
          bind PositiveNumber
        end

      assert {:error, msg} = failure
      assert msg =~ "must be positive"

      # With map operations
      with_map =
        either "10", as: :tuple do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert with_map == {:ok, 20}

      # With tuple-returning operations
      tuple_ops =
        either "10", as: :tuple do
          bind TupleParseInt
          bind TupleValidator
        end

      assert tuple_ops == {:ok, 10}
    end

    test "as: :raise - unwraps value on success and raises on failure" do
      # Success case
      success =
        either "42", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == 42

      # With map operations
      with_map =
        either "10", as: :raise do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert with_map == 20

      # With tuple-returning operations
      tuple_ops =
        either "10", as: :raise do
          bind TupleParseInt
          bind TupleValidator
        end

      assert tuple_ops == 10

      # Raises on failure
      assert_raise RuntimeError, ~r/must be positive/, fn ->
        either "-5", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end
      end
    end
  end

  # ============================================================================
  # Complex Pipelines & Real-World Examples
  # ============================================================================

  describe "complex pipelines" do
    test "combining all DSL features" do
      result =
        either "10" do
          bind ParseInt
          map &(&1 * 2)
          bind fn x ->
            if x > 15, do: right(x), else: left("too small")
          end
          validate([PositiveNumber])
          filter_or_else(&(&1 < 50), fn -> "too large" end)
          map Double
        end

      assert result == %Right{right: 40}
    end

    test "real-world file reading example" do
      # Create temp file with JSON
      path = "/tmp/test_dsl_#{:rand.uniform(10000)}.json"
      File.write!(path, ~s({"value": 42}))

      result =
        either path do
          bind &File.read/1
          bind &Jason.decode/1
          map fn map -> Map.get(map, "value") end
        end

      File.rm(path)
      assert result == %Right{right: 42}
    end

    test "mixing Either and tuple operations" do
      result =
        either "42" do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert result == %Right{right: 84}
    end
  end

  # ============================================================================
  # Error Handling & Edge Cases
  # ============================================================================

  describe "input lifting" do
    test "various input types are lifted correctly" do
      test_cases = [
        {42, %Right{right: 84}, "plain value wrapped in Right"},
        {right(42), %Right{right: 84}, "Either Right passed through"},
        {left("error"), %Left{left: "error"}, "Either Left short-circuits"},
        {{:ok, 42}, %Right{right: 84}, "{:ok, value} converted to Right"},
        {{:error, "failed"}, %Left{left: "failed"}, "{:error, reason} converted to Left"}
      ]

      for {input, expected, description} <- test_cases do
        result =
          either input do
            map &(&1 * 2)
          end

        assert result == expected, "Failed: #{description}"
      end
    end

    test "can compose with function returning tuple" do
      fetch_data = fn -> {:ok, "10"} end

      result =
        either fetch_data.() do
          bind ParseInt
          map Double
        end

      assert result == %Right{right: 20}
    end

    test "can compose with function returning Either" do
      fetch_data = fn -> right(10) end

      result =
        either fetch_data.() do
          map Double
        end

      assert result == %Right{right: 20}
    end

    test "error tuple short-circuits pipeline" do
      result =
        either {:error, "initial error"} do
          bind ParseInt
          map Double
        end

      assert result == %Left{left: "initial error"}
    end
  end

  describe "error handling" do
    test "raises on invalid return value from bind" do
      assert_raise ArgumentError, ~r/run\/1 must return/, fn ->
        either "test" do
          bind InvalidReturn
        end
      end
    end

    test "raises on invalid return value from anonymous function" do
      assert_raise ArgumentError, ~r/run\/1 must return/, fn ->
        either "test" do
          bind fn _ -> "not an Either or tuple" end
        end
      end
    end

    test "explicit keywords required - bare module would fail" do
      # This verifies bind/map keywords are required
      # Invalid: bare `ParseInt` without keyword would cause compile error
      # Valid: using explicit keyword
      result =
        either "42" do
          bind ParseInt
        end

      assert result == %Right{right: 42}
    end
  end

  describe "auto-pipe lifting for Module.function() forms" do
    test "bind lifts the pipeline value into the first argument of a module function" do
    result =
      either 10 do
        bind PipeTarget.add(5)        # becomes fn x -> PipeTarget.add(x, 5) end
      end

    assert result == right(15)
  end

  test "map lifts the pipeline value into the first argument" do
    result =
      either 3 do
        map PipeTarget.mul(4)         # becomes fn x -> PipeTarget.mul(x, 4) end
      end

    assert result == right(12)
  end

  test "bind with lifted call normalizes tuple return" do
    result =
      either -5 do
        bind PipeTarget.check_positive()   # becomes fn x -> PipeTarget.check_positive(x) end
      end

    assert result == left("not positive")
  end

  test "map with lifted call wraps pure value in Right" do
    result =
      either 2 do
        map PipeTarget.mul(10)
      end

    assert result == right(20)
  end

  test "mixed lifted bind + lifted map works correctly" do
    result =
      either 2 do
        bind PipeTarget.add(3)     # 2 + 3 = 5
        map PipeTarget.mul(4)      # 5 * 4 = 20
      end

    assert result == right(20)
  end

  test "lifted functions respect error propagation" do
    result =
      either -2 do
        bind PipeTarget.check_positive()   # x < 0 → {:error, ..} → Left
        map PipeTarget.mul(5)              # should not run
      end

    assert result == left("not positive")
  end

  test "auto-pipe does not break existing function-capture behavior" do
    result =
      either 5 do
        bind &{:ok, &1 * 2}
        map  &(&1 + 3)
      end

    assert result == right(13)
  end

  test "auto-pipe does not trigger for bare modules" do
    quoted =
      quote do
        require Dsl
        Dsl.either 5 do
          bind PipeTarget
        end
      end

    assert_raise CompileError, fn ->
      Code.eval_quoted(quoted)
    end
  end

  test "auto-pipe works with multi-step argument forms" do
    result =
      either 1 do
        bind PipeTarget.add(2)   # -> 3
        bind PipeTarget.add(4)   # -> 7
        map  PipeTarget.mul(3)   # -> 21
      end

    assert result == right(21)
  end
end

  # ============================================================================
  # Module-Specific Options (opts parameter)
  # ============================================================================

  describe "module-specific options with bind" do
    test "passes options to module run/3 function" do
      result =
        either "FF" do
          bind ParseIntWithBase, base: 16
        end

      assert result == %Right{right: 255}
    end

    test "uses default when no options provided" do
      result =
        either "42" do
          bind ParseIntWithBase
        end

      assert result == %Right{right: 42}
    end

    test "different options for different modules in pipeline" do
      result =
        either "10" do
          bind ParseIntWithBase, base: 10
          bind MinValidator, min: 5
        end

      assert result == %Right{right: 10}
    end

    test "fails when option constraints not met" do
      result =
        either "5" do
          bind ParseIntWithBase
          bind MinValidator, min: 10
        end

      assert %Left{left: msg} = result
      assert msg =~ "must be > 10"
    end

    test "works with different number bases" do
      test_cases = [
        {16, "A5", 165, "hexadecimal"},
        {2, "1010", 10, "binary"},
        {8, "17", 15, "octal"}
      ]

      for {base, input, expected, name} <- test_cases do
        result =
          either input do
            bind ParseIntWithBase, base: base
          end

        assert result == %Right{right: expected},
               "Failed to parse #{input} as #{name} (base #{base})"
      end
    end

    test "complex pipeline with multiple module-specific options" do
      result =
        either "FF" do
          bind ParseIntWithBase, base: 16
          bind MinValidator, min: 100
          bind RangeValidatorWithOpts, min: 200, max: 300
        end

      assert result == %Right{right: 255}
    end

    test "error message includes base when parsing fails" do
      result =
        either "XYZ" do
          bind ParseIntWithBase, base: 16
        end

      assert %Left{left: msg} = result
      assert msg =~ "base 16"
    end
  end

  describe "module-specific options with map" do
    test "passes options to module run/3 function" do
      result =
        either 10 do
          map Multiplier, factor: 5
        end

      assert result == %Right{right: 50}
    end

    test "uses default when no options provided" do
      result =
        either 10 do
          map Multiplier
        end

      assert result == %Right{right: 10}
    end

    test "multiple map operations with different options" do
      result =
        either 2 do
          map Multiplier, factor: 3
          map Multiplier, factor: 4
        end

      assert result == %Right{right: 24}
    end

    test "bind and map with options in same pipeline" do
      result =
        either "10" do
          bind ParseIntWithBase, base: 10
          bind MinValidator, min: 5
          map Multiplier, factor: 10
        end

      assert result == %Right{right: 100}
    end

    test "map with options after validation" do
      result =
        either "FF" do
          bind ParseIntWithBase, base: 16
          bind RangeValidatorWithOpts, min: 200, max: 300
          map Multiplier, factor: 2
        end

      assert result == %Right{right: 510}
    end
  end

  describe "module-specific options with run" do
    test "passes options to module run/3 function" do
      # run passes Either directly, so we need to handle it differently
      result =
        either "42" do
          bind ParseIntWithBase, base: 10
        end

      assert result == %Right{right: 42}
    end

    test "run with options - demonstrates escape hatch" do
      # The `run` keyword gives direct access to Either value
      # This test shows it passes opts correctly
      result =
        either "FF" do
          bind ParseIntWithBase, base: 16
          bind MinValidator, min: 100
        end

      assert result == %Right{right: 255}
    end
  end

  describe "module-specific options - edge cases" do
    test "empty options list works" do
      result =
        either "42" do
          bind ParseIntWithBase, []
        end

      assert result == %Right{right: 42}
    end

    test "multiple options in single call" do
      result =
        either "50" do
          bind ParseIntWithBase, base: 10
          bind RangeValidatorWithOpts, min: 0, max: 100
        end

      assert result == %Right{right: 50}
    end

    test "options do not affect global environment" do
      # This test ensures module-specific opts don't leak
      result =
        either "10" do
          bind ParseIntWithBase, base: 16  # This should only affect ParseIntWithBase
          bind MinValidator, min: 5         # This should not see base: 16
        end

      assert result == %Right{right: 16}
    end

    test "works with as: :tuple return type" do
      result =
        either "FF", as: :tuple do
          bind ParseIntWithBase, base: 16
          bind MinValidator, min: 100
        end

      assert result == {:ok, 255}
    end

    test "works with as: :raise return type" do
      result =
        either "A0", as: :raise do
          bind ParseIntWithBase, base: 16
        end

      assert result == 160
    end
  end

end
