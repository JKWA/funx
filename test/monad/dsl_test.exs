defmodule Funx.Monad.Either.DslTest do
  use Funx.TestCase, async: true
  use Funx.Monad.Either

  alias Funx.Monad.Either
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

  alias Funx.Monad.Either.{Left, Right}

  # Helper function to test named function partial application
  defp check_value_with_threshold(value, threshold) do
    if value > threshold, do: {:ok, value}, else: {:error, "below threshold"}
  end

  # Helper function that returns a function (like maybe_filter_closed pattern)
  defp maybe_double_if(should_double) do
    fn x -> if should_double, do: x * 2, else: x end
  end

  defmodule PipeTarget do
    @moduledoc "Module used to test auto-pipe function call rewriting"

    def add(x, amount), do: {:ok, x + amount}

    def mul(x, amount), do: x * amount

    def check_positive(x) when x > 0, do: {:ok, x}
    def check_positive(_), do: {:error, "not positive"}

    def format_error(error, context), do: "#{context}: #{error}"
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

  describe "ap keyword" do
    test "applies a function in Right to a value in Right" do
      result =
        either right(&(&1 + 1)) do
          ap right(42)
        end

      assert result == %Right{right: 43}
    end

    test "returns Left if the function is in Left" do
      result =
        either left("error") do
          ap right(42)
        end

      assert result == %Left{left: "error"}
    end

    test "returns Left if the value is in Left" do
      result =
        either right(&(&1 + 1)) do
          ap left("error")
        end

      assert result == %Left{left: "error"}
    end

    test "returns Left if both are Left" do
      result =
        either left("error1") do
          ap left("error2")
        end

      assert result == %Left{left: "error1"}
    end

    test "chains with bind and map" do
      result =
        either "10" do
          bind ParseInt
          map fn x -> &(&1 + x) end
          ap right(5)
        end

      assert result == %Right{right: 15}
    end

    test "applies a function from previous step" do
      result =
        either 5 do
          map fn x -> &(&1 + x) end
          ap right(10)
        end

      assert result == %Right{right: 15}
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

    test "with stdlib function and additional arguments" do
      result =
        either 5 do
          map to_string()
          map String.pad_leading(3, "0")
        end

      assert result == %Right{right: "005"}
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

    test "with function that returns a function" do
      make_multiplier = fn factor -> fn x -> x * factor end end

      result =
        either 5 do
          map make_multiplier.(3)
        end

      assert result == %Right{right: 15}
    end

    test "with helper function that returns a function (like maybe_filter pattern)" do
      maybe_double = fn should_double ->
        fn x -> if should_double, do: x * 2, else: x end
      end

      result =
        either 5 do
          map maybe_double.(true)
        end

      assert result == %Right{right: 10}

      result2 =
        either 5 do
          map maybe_double.(false)
        end

      assert result2 == %Right{right: 5}
    end

    test "with named function partial application (like check_no_other_assignments pattern)" do
      # Test the pattern: bind check_value_with_threshold(10)
      # This should lift to: fn x -> check_value_with_threshold(x, 10) end
      # because check_value_with_threshold/2 exists
      result =
        either 15 do
          bind check_value_with_threshold(10)
        end

      assert result == %Right{right: 15}

      result2 =
        either 5 do
          bind check_value_with_threshold(10)
        end

      assert result2 == %Left{left: "below threshold"}
    end

    test "with function that returns a function (like maybe_filter_closed pattern)" do
      # Test the pattern: map maybe_double_if(true)
      # This should NOT be lifted because maybe_double_if/1 exists but maybe_double_if/2 doesn't
      # So it will call maybe_double_if(true) which returns a function, then use that function
      result =
        either 5 do
          map maybe_double_if(true)
        end

      assert result == %Right{right: 10}

      result2 =
        either 5 do
          map maybe_double_if(false)
        end

      assert result2 == %Right{right: 5}
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

  # ============================================================================
  # Either Module Functions (auto-imported)
  # ============================================================================

  describe "Either module functions" do
    test "validate with list of validators" do
      result =
        either "10" do
          bind ParseInt
          validate [PositiveNumber, RangeValidator]
        end

      assert result == %Right{right: 10}
    end

    test "validate accumulates errors from all validators" do
      result =
        either "-5" do
          bind ParseInt
          validate [PositiveNumber, RangeValidator]
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert length(errors) == 2
    end

    test "validate with module-specific options" do
      result =
        either "50" do
          bind ParseInt
          validate [{RangeValidator, min: 0, max: 100}, {MinValidator, min: 10}]
        end

      assert result == %Right{right: 50}
    end

    test "validate with mixed bare and tuple syntax" do
      result =
        either "50" do
          bind ParseInt
          validate [PositiveNumber, {RangeValidator, min: 0, max: 100}, {MinValidator, min: 10}]
        end

      assert result == %Right{right: 50}
    end

    test "validate accumulates errors with options" do
      result =
        either "-5" do
          bind ParseInt
          validate [PositiveNumber, {RangeValidator, min: 0, max: 100}, {MinValidator, min: 0}]
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert length(errors) == 3
    end

    test "validate with empty options list in tuple" do
      result =
        either "50" do
          bind ParseInt
          validate [{RangeValidator, []}]
        end

      assert result == %Right{right: 50}
    end

    test "validate options are isolated per validator" do
      result =
        either "5" do
          bind ParseInt

          validate [
            {RangeValidator, min: 0, max: 10},
            {MinValidator, min: 3}
          ]
        end

      assert result == %Right{right: 5}

      result_fail =
        either "5" do
          bind ParseInt

          validate [
            {RangeValidator, min: 10, max: 20},
            {MinValidator, min: 1}
          ]
        end

      assert %Left{left: errors} = result_fail
      assert is_list(errors)
      assert length(errors) == 1
      assert hd(errors) =~ "must be between 10 and 20"
    end

    test "filter_or_else passes when predicate is true" do
      result =
        either "10" do
          bind ParseInt
          filter_or_else &(&1 < 50), fn -> "too large" end
        end

      assert result == %Right{right: 10}
    end

    test "filter_or_else fails when predicate is false" do
      result =
        either "100" do
          bind ParseInt
          filter_or_else &(&1 < 50), fn -> "too large" end
        end

      assert result == %Left{left: "too large"}
    end

    test "or_else provides fallback on failure" do
      result =
        either "-5" do
          bind ParseInt
          bind PositiveNumber
          or_else fn -> right(42) end
        end

      assert result == %Right{right: 42}
    end

    test "or_else passes through success" do
      result =
        either "10" do
          bind ParseInt
          bind PositiveNumber
          or_else fn -> right(42) end
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
      success =
        either "42", as: :tuple do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == {:ok, 42}

      failure =
        either "-5", as: :tuple do
          bind ParseInt
          bind PositiveNumber
        end

      assert {:error, msg} = failure
      assert msg =~ "must be positive"

      with_map =
        either "10", as: :tuple do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert with_map == {:ok, 20}

      tuple_ops =
        either "10", as: :tuple do
          bind TupleParseInt
          bind TupleValidator
        end

      assert tuple_ops == {:ok, 10}
    end

    test "as: :raise - unwraps value on success and raises on failure" do
      success =
        either "42", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == 42

      with_map =
        either "10", as: :raise do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert with_map == 20

      tuple_ops =
        either "10", as: :raise do
          bind TupleParseInt
          bind TupleValidator
        end

      assert tuple_ops == 10

      assert_raise RuntimeError, ~r/must be positive/, fn ->
        either "-5", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end
      end
    end

    test "as: :either validates result is an Either struct" do
      # This should work - returns Either
      result =
        either "42", as: :either do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Right{right: 42}

      # Failure case also returns Either
      failure =
        either "-5", as: :either do
          bind ParseInt
          bind PositiveNumber
        end

      assert %Left{} = failure
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

          validate [PositiveNumber]
          filter_or_else &(&1 < 50), fn -> "too large" end
          map Double
        end

      assert result == %Right{right: 40}
    end

    test "real-world file reading example" do
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
      assert_raise ArgumentError, ~r/run\/3 callback must return/, fn ->
        either "test" do
          bind InvalidReturn
        end
      end
    end

    test "raises on invalid return value from anonymous function" do
      assert_raise ArgumentError, ~r/run\/3 callback must return/, fn ->
        either "test" do
          bind fn _ -> "not an Either or tuple" end
        end
      end
    end

    test "explicit keywords required - bare module would fail" do
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
          bind PipeTarget.add(5)
        end

      assert result == right(15)
    end

    test "map lifts the pipeline value into the first argument" do
      result =
        either 3 do
          map PipeTarget.mul(4)
        end

      assert result == right(12)
    end

    test "bind with lifted call normalizes tuple return" do
      result =
        either -5 do
          bind PipeTarget.check_positive()
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
          bind PipeTarget.add(3)
          map PipeTarget.mul(4)
        end

      assert result == right(20)
    end

    test "lifted functions respect error propagation" do
      result =
        either -2 do
          bind PipeTarget.check_positive()
          map PipeTarget.mul(5)
        end

      assert result == left("not positive")
    end

    test "auto-pipe does not break existing function-capture behavior" do
      result =
        either 5 do
          bind &{:ok, &1 * 2}
          map &(&1 + 3)
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
          bind PipeTarget.add(2)
          bind PipeTarget.add(4)
          map PipeTarget.mul(3)
        end

      assert result == right(21)
    end
  end

  describe "auto-pipe lifting in validate lists" do
    # Helper module with zero-arity validator function
    defmodule ValidatorHelpers do
      import Funx.Monad.Either

      def positive?(x) do
        if x > 0, do: right(x), else: left("must be positive: #{x}")
      end

      def even?(x) do
        if rem(x, 2) == 0, do: right(x), else: left("must be even: #{x}")
      end

      def less_than(x, max) do
        if x < max, do: right(x), else: left("must be less than #{max}: #{x}")
      end
    end

    test "validate with zero-arity function calls gets auto-lifted" do
      result =
        either 4 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.even?()]
        end

      assert result == %Right{right: 4}
    end

    test "validate with zero-arity function calls accumulates errors" do
      result =
        either -3 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.even?()]
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert length(errors) == 2
      assert Enum.any?(errors, &String.contains?(&1, "must be positive"))
      assert Enum.any?(errors, &String.contains?(&1, "must be even"))
    end

    test "validate with function calls with args gets auto-lifted" do
      result =
        either 5 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.less_than(10)]
        end

      assert result == %Right{right: 5}
    end

    test "validate with function calls with args fails when condition not met" do
      result =
        either 15 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.less_than(10)]
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert length(errors) == 1
      assert hd(errors) =~ "must be less than 10"
    end

    test "validate mixes modules and auto-lifted functions" do
      result =
        either 5 do
          validate [ValidatorHelpers.positive?(), PositiveNumber, ValidatorHelpers.even?()]
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      # even? should fail
      assert Enum.any?(errors, &String.contains?(&1, "must be even"))
    end

    test "validate with modules, tuples, and auto-lifted functions" do
      result =
        either 50 do
          validate [
            ValidatorHelpers.positive?(),
            {RangeValidator, min: 0, max: 100},
            ValidatorHelpers.even?()
          ]
        end

      assert result == %Right{right: 50}
    end

    test "validate auto-lifting works with single validator" do
      result =
        either 10 do
          validate ValidatorHelpers.positive?()
        end

      assert result == %Right{right: 10}
    end

    test "validate auto-lifting fails properly with single validator" do
      result =
        either -5 do
          validate ValidatorHelpers.positive?()
        end

      assert %Left{left: errors} = result
      assert is_list(errors)
      assert hd(errors) =~ "must be positive"
    end

    test "chained validate with auto-lifted functions" do
      result =
        either 4 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.even?()]
          validate ValidatorHelpers.less_than(10)
        end

      assert result == %Right{right: 4}
    end

    test "auto-lifted functions respect arity checking" do
      # less_than/2 when called with one arg should be lifted to fn x -> less_than(x, 100) end
      result =
        either 50 do
          validate [ValidatorHelpers.positive?(), ValidatorHelpers.less_than(100)]
        end

      assert result == %Right{right: 50}
    end

    test "zero-arity qualified calls are lifted in bind" do
      # Module.fun() should become &Module.fun/1 in bind
      result =
        either 5 do
          bind PipeTarget.check_positive()
        end

      assert result == %Right{right: 5}
    end

    test "zero-arity qualified calls are lifted in map" do
      # Module.fun() should become &Module.fun/1 in map
      result =
        either "hello" do
          map String.upcase()
        end

      assert result == %Right{right: "HELLO"}
    end

    test "zero-arity qualified calls work with error cases" do
      result =
        either -5 do
          bind PipeTarget.check_positive()
        end

      assert result == %Left{left: "not positive"}
    end
  end

  # ============================================================================
  # Module-Specific Options (opts parameter)
  # ============================================================================

  describe "module-specific options with bind" do
    test "passes options to module run/3 function" do
      result =
        either "FF" do
          bind {ParseIntWithBase, base: 16}
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
          bind {ParseIntWithBase, base: 10}
          bind {MinValidator, min: 5}
        end

      assert result == %Right{right: 10}
    end

    test "fails when option constraints not met" do
      result =
        either "5" do
          bind ParseIntWithBase
          bind {MinValidator, min: 10}
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
            bind {ParseIntWithBase, base: base}
          end

        assert result == %Right{right: expected},
               "Failed to parse #{input} as #{name} (base #{base})"
      end
    end

    test "complex pipeline with multiple module-specific options" do
      result =
        either "FF" do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 100}
          bind {RangeValidatorWithOpts, min: 200, max: 300}
        end

      assert result == %Right{right: 255}
    end

    test "error message includes base when parsing fails" do
      result =
        either "XYZ" do
          bind {ParseIntWithBase, base: 16}
        end

      assert %Left{left: msg} = result
      assert msg =~ "base 16"
    end
  end

  describe "module-specific options with map" do
    test "passes options to module run/3 function" do
      result =
        either 10 do
          map {Multiplier, factor: 5}
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
          map {Multiplier, factor: 3}
          map {Multiplier, factor: 4}
        end

      assert result == %Right{right: 24}
    end

    test "bind and map with options in same pipeline" do
      result =
        either "10" do
          bind {ParseIntWithBase, base: 10}
          bind {MinValidator, min: 5}
          map {Multiplier, factor: 10}
        end

      assert result == %Right{right: 100}
    end

    test "map with options after validation" do
      result =
        either "FF" do
          bind {ParseIntWithBase, base: 16}
          bind {RangeValidatorWithOpts, min: 200, max: 300}
          map {Multiplier, factor: 2}
        end

      assert result == %Right{right: 510}
    end
  end

  describe "module-specific options" do
    test "passes options to module run/3 function" do
      result =
        either "42" do
          bind {ParseIntWithBase, base: 10}
        end

      assert result == %Right{right: 42}
    end

    test "bind with options" do
      result =
        either "FF" do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 100}
        end

      assert result == %Right{right: 255}
    end
  end

  describe "module-specific options - edge cases" do
    test "empty options list works" do
      result =
        either "42" do
          bind {ParseIntWithBase, []}
        end

      assert result == %Right{right: 42}
    end

    test "multiple options in single call" do
      result =
        either "50" do
          bind {ParseIntWithBase, base: 10}
          bind {RangeValidatorWithOpts, min: 0, max: 100}
        end

      assert result == %Right{right: 50}
    end

    test "options do not affect global environment" do
      result =
        either "10" do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 5}
        end

      assert result == %Right{right: 16}
    end

    test "works with as: :tuple return type" do
      result =
        either "FF", as: :tuple do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 100}
        end

      assert result == {:ok, 255}
    end

    test "works with as: :raise return type" do
      result =
        either "A0", as: :raise do
          bind {ParseIntWithBase, base: 16}
        end

      assert result == 160
    end
  end

  describe "whitelisted Either functions" do
    test "allows filter_or_else/3" do
      result =
        either 5 do
          filter_or_else &(&1 > 3), fn -> "too small" end
        end

      assert result == %Right{right: 5}
    end

    test "allows or_else/2" do
      result =
        either left("error") do
          or_else fn -> right(42) end
        end

      assert result == %Right{right: 42}
    end

    test "allows map_left/2" do
      result =
        either left("error") do
          map_left fn e -> "wrapped: " <> e end
        end

      assert result == %Left{left: "wrapped: error"}
    end

    test "map_left with auto-lifting" do
      # Verify that map_left receives the lifted function
      # We use an anonymous function variable to avoid compile-time evaluation
      format_fn = &PipeTarget.format_error(&1, "validation")

      result =
        either left("failed") do
          map_left format_fn
        end

      assert result == %Left{left: "validation: failed"}
    end

    test "allows flip/1" do
      result =
        either left("error") do
          flip()
        end

      assert result == %Right{right: "error"}
    end

    test "allows validate/2" do
      result =
        either 4 do
          map(&(&1 + 1))
          validate [PositiveNumber]
        end

      assert result == %Right{right: 5}
    end
  end

  # ============================================================================
  # Compile-Time Error Handling
  # ============================================================================

  describe "compile-time error handling" do
    test "raises on invalid return type option" do
      assert_raise CompileError, ~r/Invalid return type/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42", as: :invalid_type do
              bind fn x -> right(x) end
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when using non-whitelisted Either function" do
      assert_raise CompileError, ~r/Invalid operation/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42" do
              bind fn x -> right(x) end
              non_existent_either_function()
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises on invalid operation type in first position" do
      assert_raise CompileError, ~r/Invalid operation/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42" do
              :some_random_atom
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises on invalid operation type in subsequent position" do
      assert_raise CompileError, ~r/Invalid operation/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42" do
              bind ParseInt
              123
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when module doesn't exist at compile time" do
      assert_raise CompileError, ~r/is not available at compile time/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42" do
              bind NonExistentModuleThatDoesNotExist
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when module doesn't implement run/3" do
      defmodule TestModuleWithoutRun do
        def some_function(x), do: x
      end

      assert_raise CompileError, ~r/must implement run\/3/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either "42" do
              bind TestModuleWithoutRun
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when validator list contains number literal" do
      assert_raise CompileError, ~r/Invalid validator in list/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either 5 do
              validate [1, 2, 3]
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when validator list contains string literal" do
      assert_raise CompileError, ~r/Invalid validator in list/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either 5 do
              validate ["not", "a", "function"]
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when validator list contains map literal" do
      assert_raise CompileError, ~r/Invalid validator in list/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either 5 do
              validate [%{key: :value}]
            end
          end,
          [],
          __ENV__
        )
      end
    end

    test "raises when bare function call used in pipeline" do
      assert_raise CompileError, ~r/Bare function calls are not allowed/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            either 5 do
              some_function(1, 2)
            end
          end,
          [],
          __ENV__
        )
      end
    end
  end

  describe "compile-time bind validation" do
    import ExUnit.CaptureIO

    test "warns when bind returns plain string literal" do
      warning =
        capture_io(:stderr, fn ->
          # Catch the runtime error that occurs after compilation
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> "plain string" end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "plain string"
    end

    test "warns when bind returns plain number literal" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> 42 end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "42"
    end

    test "warns when bind returns plain atom literal" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> :some_atom end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ ":some_atom"
    end

    test "warns when bind returns plain map literal" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> %{key: "value"} end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "%{key: \"value\"}"
    end

    test "warns when bind returns plain list literal" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> [1, 2, 3] end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "[1, 2, 3]"
    end

    test "warns when bind returns nil" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> nil end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "nil"
    end

    test "warns when bind returns true" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> true end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "true"
    end

    test "warns when bind returns false" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn _ -> false end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "false"
    end

    test "warns for plain return in multi-clause function" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either 0 do
                  bind fn
                    0 -> "zero"
                    x -> right(x)
                  end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "zero"
    end

    test "warns for plain return in block expression" do
      warning =
        capture_io(:stderr, fn ->
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                either "test" do
                  bind fn x ->
                    _discarded = x
                    "return value"
                  end
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      assert warning =~ "Potential type error in bind operation"
      assert warning =~ "return value"
    end

    test "does not warn when bind returns Either constructor (right)" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn x -> right(x) end
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn when bind returns Either constructor (left)" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn _ -> left("error") end
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn when bind returns qualified Funx.Monad.Either constructor" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn x -> Either.right(x) end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn when bind returns :ok tuple" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn x -> {:ok, x} end
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn when bind returns :error tuple" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn _ -> {:error, "reason"} end
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn for complex expressions (variables)" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              result = right("test")

              either "input" do
                bind fn _ -> result end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn for complex expressions (case statement)" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind fn x ->
                  case x do
                    "good" -> right(x)
                    _ -> left("bad")
                  end
                end
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn for modules with run/3" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                bind ParseInt
              end
            end
          )
        end)

      assert warning == ""
    end

    test "does not warn for function references" do
      warning =
        capture_io(:stderr, fn ->
          # Function references can't be analyzed at compile time
          # This will fail at runtime but shouldn't emit compile-time warnings
          catch_error(
            Code.eval_quoted(
              quote do
                require Funx.Monad.Either.Dsl
                import Funx.Monad.Either.Dsl

                defmodule TestHelper do
                  def make_right(x), do: right(x)
                end

                either "test" do
                  bind &TestHelper.make_right/1
                end
              end,
              [],
              __ENV__
            )
          )
        end)

      # Should have no compile-time warnings (runtime errors are fine)
      refute warning =~ "Potential type error in bind operation"
    end
  end

  describe "compile-time map validation" do
    import ExUnit.CaptureIO

    test "warns when map returns Either constructor (right)" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> right(x) end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "right(x)"
    end

    test "warns when map returns Either constructor (left)" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn _ -> left("error") end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "left"
    end

    test "warns when map returns qualified Funx.Monad.Either constructor" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> Either.right(x) end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "Either.right"
    end

    test "warns when map returns :ok tuple" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> {:ok, x} end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "{:ok, x}"
    end

    test "warns when map returns :error tuple" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn _ -> {:error, "reason"} end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "{:error"
    end

    test "warns for Either return in multi-clause function" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either 0 do
                map fn
                  0 -> right("zero")
                  x -> x
                end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "right"
    end

    test "warns for Either return in block expression" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x ->
                  _discarded = x
                  right("wrapped")
                end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning =~ "Potential incorrect usage of map operation"
      assert warning =~ "right"
    end

    test "does not warn when map returns plain string" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> "plain: #{x}" end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn when map returns plain number" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either 10 do
                map fn x -> x * 2 end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn when map returns plain atom" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn _ -> :some_atom end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn when map returns plain map" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> %{value: x} end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn when map returns plain list" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> [x, x] end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn for complex expressions (variables)" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x -> x end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn for complex expressions (case statement)" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map fn x ->
                  case x do
                    "good" -> "GOOD"
                    _ -> "BAD"
                  end
                end
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn for modules with run/3" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map ParseInt
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end

    test "does not warn for function references" do
      warning =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Funx.Monad.Either.Dsl
              import Funx.Monad.Either.Dsl

              either "test" do
                map &String.upcase/1
              end
            end,
            [],
            __ENV__
          )
        end)

      assert warning == ""
    end
  end
end
