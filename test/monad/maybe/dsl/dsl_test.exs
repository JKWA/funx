defmodule Funx.Monad.Maybe.DslTest do
  @moduledoc """
  Integration tests for the Maybe DSL.

  This file serves as the specification for the Maybe DSL runtime behavior.
  It tests the DSL's execution semantics including:
  - Core operations (bind, map, ap)
  - Auto-lifting transformations (Module.function() forms)
  - Tuple/Maybe interop and normalization
  - Return type transformations (:maybe, :raise, :nil)
  - Maybe-specific functions (or_else, filter, filter_map, tap)
  - Module-specific options passing
  - Nothing propagation through pipelines

  For compile-time parsing and AST transformation tests, see parser_test.exs.
  """

  use Funx.TestCase, async: true

  doctest Funx.Monad.Maybe.Dsl
  doctest Funx.Monad.Maybe.Dsl.Behaviour

  use Funx.Monad.Maybe
  use Funx.Monad.Either

  alias Funx.Monad.Maybe.Dsl

  alias Funx.Monad.Maybe.Dsl.Examples.{
    Double,
    InRange,
    InvalidReturn,
    IsPositive,
    Logger,
    MinValidator,
    Multiplier,
    ParseInt,
    ParseIntWithBase,
    PositiveNumber,
    TupleParseInt,
    TupleValidator
  }

  alias Funx.Monad.Maybe.{Just, Nothing}

  # Helper function to test named function partial application
  defp check_value_with_threshold(value, threshold) do
    if value > threshold, do: {:ok, value}, else: {:error, "below threshold"}
  end

  defmodule PipeTarget do
    @moduledoc "Module used to test auto-pipe function call rewriting"

    def add(x, amount), do: {:ok, x + amount}

    def mul(x, amount), do: x * amount

    def check_positive(x) when x > 0, do: {:ok, x}
    def check_positive(_), do: {:error, "not positive"}
  end

  # ============================================================================
  # Core DSL Keywords - bind, map
  # ============================================================================

  # Tests bind semantics, including tuple/Maybe normalization and Nothing propagation
  describe "bind keyword" do
    test "with module returning Maybe" do
      result =
        maybe "42" do
          bind ParseInt
        end

      assert result == %Just{value: 42}
    end

    test "with module returning tuple" do
      result =
        maybe "42" do
          bind TupleParseInt
        end

      assert result == %Just{value: 42}
    end

    test "with anonymous function returning Maybe" do
      result =
        maybe "42" do
          bind fn x ->
            case Integer.parse(x) do
              {int, ""} -> just(int)
              _ -> nothing()
            end
          end
        end

      assert result == %Just{value: 42}
    end

    test "with anonymous function returning tuple" do
      result =
        maybe "42" do
          bind fn x ->
            case Integer.parse(x) do
              {int, ""} -> {:ok, int}
              _ -> {:error, "invalid"}
            end
          end
        end

      assert result == %Just{value: 42}
    end

    test "with capture syntax" do
      parse_int = fn x ->
        case Integer.parse(x) do
          {int, ""} -> {:ok, int}
          _ -> {:error, "invalid"}
        end
      end

      result =
        maybe "42" do
          bind &parse_int.(&1)
        end

      assert result == %Just{value: 42}
    end

    test "propagates Nothing correctly" do
      result =
        maybe "-5" do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Nothing{}
    end

    test "chains multiple bind operations" do
      result =
        maybe "42" do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Just{value: 42}
    end
  end

  # Tests applicative functor semantics for applying wrapped functions
  describe "ap keyword" do
    test "applies a function in Just to a value in Just" do
      result =
        maybe just(&(&1 + 1)) do
          ap just(42)
        end

      assert result == %Just{value: 43}
    end

    test "returns Nothing if the function is Nothing" do
      result =
        maybe nothing() do
          ap just(42)
        end

      assert result == %Nothing{}
    end

    test "returns Nothing if the value is Nothing" do
      result =
        maybe just(&(&1 + 1)) do
          ap nothing()
        end

      assert result == %Nothing{}
    end

    test "returns Nothing if both are Nothing" do
      result =
        maybe nothing() do
          ap nothing()
        end

      assert result == %Nothing{}
    end

    test "chains with bind and map" do
      result =
        maybe "10" do
          bind ParseInt
          map fn x -> &(&1 + x) end
          ap just(5)
        end

      assert result == %Just{value: 15}
    end
  end

  # Tests map (Functor) semantics for pure transformations
  describe "map keyword" do
    test "with module" do
      result =
        maybe "10" do
          bind ParseInt
          map Double
        end

      assert result == %Just{value: 20}
    end

    test "with stdlib function" do
      result =
        maybe "10" do
          bind ParseInt
          map &to_string/1
        end

      assert result == %Just{value: "10"}
    end

    test "with stdlib function and additional arguments" do
      result =
        maybe 5 do
          map to_string()
          map String.pad_leading(3, "0")
        end

      assert result == %Just{value: "005"}
    end

    test "with capture syntax &(&1 * 2)" do
      result =
        maybe "10" do
          bind ParseInt
          map &(&1 * 2)
        end

      assert result == %Just{value: 20}
    end

    test "with anonymous function" do
      result =
        maybe "10" do
          bind ParseInt
          map fn x -> x * 2 end
        end

      assert result == %Just{value: 20}
    end

    test "with named function partial application" do
      result =
        maybe 15 do
          bind check_value_with_threshold(10)
        end

      assert result == %Just{value: 15}

      result2 =
        maybe 5 do
          bind check_value_with_threshold(10)
        end

      assert result2 == %Nothing{}
    end
  end

  # ============================================================================
  # Maybe Module Functions
  # ============================================================================

  # Tests Maybe-specific functions: or_else, filter, guard, filter_map, tap
  describe "Maybe module functions" do
    test "or_else provides fallback on Nothing" do
      result =
        maybe "-5" do
          bind ParseInt
          bind PositiveNumber
          or_else fn -> just(42) end
        end

      assert result == %Just{value: 42}
    end

    test "or_else passes through Just" do
      result =
        maybe "10" do
          bind ParseInt
          bind PositiveNumber
          or_else fn -> just(42) end
        end

      assert result == %Just{value: 10}
    end

    test "filter keeps value when predicate is true" do
      result =
        maybe "10" do
          bind ParseInt
          filter(&(&1 < 50))
        end

      assert result == %Just{value: 10}
    end

    test "filter returns Nothing when predicate is false" do
      result =
        maybe "100" do
          bind ParseInt
          filter(&(&1 < 50))
        end

      assert result == %Nothing{}
    end

    test "filter_map applies function and filters" do
      result =
        maybe [1, 2, 3, 4, 5] do
          filter_map(fn list ->
            evens = Enum.filter(list, &(rem(&1, 2) == 0))
            if evens == [], do: nothing(), else: just(evens)
          end)
        end

      assert result == %Just{value: [2, 4]}
    end

    test "filter_map returns Nothing when function returns Nothing" do
      result =
        maybe [1, 3, 5] do
          filter_map(fn list ->
            evens = Enum.filter(list, &(rem(&1, 2) == 0))
            if evens == [], do: nothing(), else: just(evens)
          end)
        end

      assert result == %Nothing{}
    end

    test "tap executes side effect on Just" do
      test_pid = self()

      result =
        maybe 5 do
          map(&(&1 * 2))
          tap(fn x -> send(test_pid, {:tapped, x}) end)
          map(&(&1 + 1))
        end

      assert result == %Just{value: 11}
      assert_received {:tapped, 10}
    end

    test "tap skips side effect on Nothing" do
      result =
        maybe nothing() do
          tap(fn x -> send(self(), {:should_not_tap, x}) end)
        end

      assert result == %Nothing{}
      refute_received {:should_not_tap, _}
    end
  end

  # ============================================================================
  # Tuple Support (interop with {:ok, value} / {:error, reason})
  # ============================================================================

  # Tests automatic normalization between {:ok, _}/{:error, _} tuples and Maybe structs
  describe "tuple/Maybe interop" do
    test "normalizes {:ok, value} to Just" do
      result =
        maybe "42" do
          bind TupleParseInt
        end

      assert result == %Just{value: 42}
    end

    test "normalizes {:error, reason} to Nothing" do
      result =
        maybe "abc" do
          bind TupleParseInt
        end

      assert result == %Nothing{}
    end

    test "chains tuple and Maybe operations" do
      result =
        maybe "10" do
          bind ParseInt
          bind TupleValidator
          bind PositiveNumber
          map Double
        end

      assert result == %Just{value: 20}
    end

    test "tuple followed by map" do
      result =
        maybe "5" do
          bind TupleParseInt
          map Double
        end

      assert result == %Just{value: 10}
    end

    test "handles tuple errors in chain" do
      result =
        maybe "-5" do
          bind ParseInt
          bind TupleValidator
        end

      assert result == %Nothing{}
    end
  end

  # ============================================================================
  # Nil Support (normalization of nil to Nothing)
  # ============================================================================

  # Tests automatic normalization of nil to Nothing in bind operations
  describe "nil/Maybe interop" do
    test "normalizes nil to Nothing in bind" do
      result =
        maybe 42 do
          bind fn _ -> nil end
        end

      assert result == %Nothing{}
    end

    test "normalizes nil in module returning nil" do
      defmodule ReturnsNil do
        @behaviour Funx.Monad.Maybe.Dsl.Behaviour
        def run(_value, _opts, _user_env), do: nil
      end

      result =
        maybe "42" do
          bind ParseInt
          bind ReturnsNil
        end

      assert result == %Nothing{}
    end

    test "chains nil and Maybe operations" do
      result =
        maybe "10" do
          bind ParseInt
          bind fn x -> if x > 100, do: x, else: nil end
          map Double
        end

      assert result == %Nothing{}
    end

    test "nil followed by map (which is skipped)" do
      result =
        maybe "5" do
          bind fn _ -> nil end
          map Double
        end

      assert result == %Nothing{}
    end

    test "handles nil in complex chain" do
      result =
        maybe "42" do
          bind ParseInt
          bind fn x -> if x == 42, do: just(x * 2), else: nil end
          map Double
        end

      assert result == %Just{value: 168}

      result2 =
        maybe "10" do
          bind ParseInt
          bind fn x -> if x == 42, do: just(x * 2), else: nil end
          map Double
        end

      assert result2 == %Nothing{}
    end

    test "mixed nil, tuple, and Maybe returns in pipeline" do
      result =
        maybe "10" do
          bind ParseInt
          bind fn x -> {:ok, x * 2} end
          bind fn x -> if x > 100, do: just(x), else: nil end
        end

      assert result == %Nothing{}

      result2 =
        maybe "60" do
          bind ParseInt
          bind fn x -> {:ok, x * 2} end
          bind fn x -> if x > 100, do: just(x), else: nil end
        end

      assert result2 == %Just{value: 120}
    end
  end

  # ============================================================================
  # Return Type Options (as: :maybe | :raise | nil)
  # ============================================================================

  # Tests return type transformations: :maybe (default), :raise, nil
  describe "return type options" do
    test "default is :maybe" do
      result =
        maybe "42" do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Just{value: 42}
    end

    test "as: :maybe (explicit)" do
      result =
        maybe "42", as: :maybe do
          bind ParseInt
        end

      assert result == %Just{value: 42}
    end

    test "as: :raise - unwraps value on Just and raises on Nothing" do
      success =
        maybe "42", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == 42

      with_map =
        maybe "10", as: :raise do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert with_map == 20

      assert_raise RuntimeError, "Nothing value encountered", fn ->
        maybe "-5", as: :raise do
          bind ParseInt
          bind PositiveNumber
        end
      end
    end

    test "as: nil - returns value or nil" do
      success =
        maybe "42", as: nil do
          bind ParseInt
          bind PositiveNumber
        end

      assert success == 42

      failure =
        maybe "-5", as: nil do
          bind ParseInt
          bind PositiveNumber
        end

      assert failure == nil
    end

    test "as: :maybe validates result is a Maybe struct" do
      result =
        maybe "42", as: :maybe do
          bind ParseInt
          bind PositiveNumber
        end

      assert result == %Just{value: 42}

      failure =
        maybe "-5", as: :maybe do
          bind ParseInt
          bind PositiveNumber
        end

      assert %Nothing{} = failure
    end

    test "raises CompileError for invalid return type option" do
      assert_raise CompileError, ~r/Invalid return type/, fn ->
        Code.eval_quoted(
          quote do
            require Dsl
            import Dsl

            maybe "42", as: :invalid_type do
              bind fn x -> just(x) end
            end
          end,
          [],
          __ENV__
        )
      end
    end
  end

  # ============================================================================
  # Complex Pipelines & Real-World Examples
  # ============================================================================

  # Tests end-to-end pipelines combining multiple DSL features
  describe "complex pipelines" do
    test "combining all DSL features" do
      result =
        maybe "10" do
          bind ParseInt
          map &(&1 * 2)

          bind fn x ->
            if x > 15, do: just(x), else: nothing()
          end

          filter(&(&1 < 50))
          map Double
        end

      assert result == %Just{value: 40}
    end

    test "real-world file reading example" do
      path = "/tmp/test_maybe_dsl_#{:rand.uniform(10000)}.json"
      File.write!(path, ~s({"value": 42}))

      result =
        maybe path do
          bind &File.read/1
          bind &Jason.decode/1
          map fn map -> Map.get(map, "value") end
        end

      File.rm(path)
      assert result == %Just{value: 42}
    end

    test "mixing Maybe and tuple operations" do
      result =
        maybe "42" do
          bind ParseInt
          bind PositiveNumber
          map Double
        end

      assert result == %Just{value: 84}
    end
  end

  # ============================================================================
  # Error Handling & Edge Cases
  # ============================================================================

  # Tests automatic lifting of various input types into Maybe context
  describe "input lifting" do
    test "various input types are lifted correctly" do
      test_cases = [
        {42, %Just{value: 84}, "plain value wrapped in Just"},
        {just(42), %Just{value: 84}, "Maybe Just passed through"},
        {nothing(), %Nothing{}, "Maybe Nothing short-circuits"},
        {{:ok, 42}, %Just{value: 84}, "{:ok, value} converted to Just"},
        {{:error, "failed"}, %Nothing{}, "{:error, reason} converted to Nothing"},
        {nil, %Nothing{}, "nil converted to Nothing"},
        {right(42), %Just{value: 84}, "Either Right converted to Just"},
        {left("error"), %Nothing{}, "Either Left converted to Nothing"}
      ]

      for {input, expected, description} <- test_cases do
        result =
          maybe input do
            map &(&1 * 2)
          end

        assert result == expected, "Failed: #{description}"
      end
    end

    test "can compose with function returning tuple" do
      fetch_data = fn -> {:ok, "10"} end

      result =
        maybe fetch_data.() do
          bind ParseInt
          map Double
        end

      assert result == %Just{value: 20}
    end

    test "can compose with function returning Maybe" do
      fetch_data = fn -> just(10) end

      result =
        maybe fetch_data.() do
          map Double
        end

      assert result == %Just{value: 20}
    end

    test "error tuple short-circuits pipeline" do
      result =
        maybe {:error, "initial error"} do
          bind ParseInt
          map Double
        end

      assert result == %Nothing{}
    end

    test "nil short-circuits pipeline" do
      result =
        maybe nil do
          bind ParseInt
          map Double
        end

      assert result == %Nothing{}
    end
  end

  # Tests runtime error handling for invalid module callbacks
  describe "error handling" do
    test "raises on invalid return value from bind" do
      assert_raise ArgumentError, ~r/run\/3 callback must return/, fn ->
        maybe "test" do
          bind InvalidReturn
        end
      end
    end

    test "raises on invalid return value from anonymous function" do
      assert_raise ArgumentError, ~r/run\/3 callback must return/, fn ->
        maybe "test" do
          bind fn _ -> "not a Maybe or tuple" end
        end
      end
    end
  end

  # Tests auto-lifting of Module.function(args) to fn x -> Module.function(x, args) end
  describe "auto-pipe lifting for Module.function() forms" do
    test "bind lifts the pipeline value into the first argument of a module function" do
      result =
        maybe 10 do
          bind PipeTarget.add(5)
        end

      assert result == just(15)
    end

    test "map lifts the pipeline value into the first argument" do
      result =
        maybe 3 do
          map PipeTarget.mul(4)
        end

      assert result == just(12)
    end

    test "bind with lifted call normalizes tuple return" do
      result =
        maybe -5 do
          bind PipeTarget.check_positive()
        end

      assert result == nothing()
    end

    test "map with lifted call wraps pure value in Just" do
      result =
        maybe 2 do
          map PipeTarget.mul(10)
        end

      assert result == just(20)
    end

    test "mixed lifted bind + lifted map works correctly" do
      result =
        maybe 2 do
          bind PipeTarget.add(3)
          map PipeTarget.mul(4)
        end

      assert result == just(20)
    end

    test "lifted functions respect Nothing propagation" do
      result =
        maybe -2 do
          bind PipeTarget.check_positive()
          map PipeTarget.mul(5)
        end

      assert result == nothing()
    end

    test "zero-arity qualified calls are lifted in bind" do
      result =
        maybe 5 do
          bind PipeTarget.check_positive()
        end

      assert result == %Just{value: 5}
    end

    test "zero-arity qualified calls are lifted in map" do
      result =
        maybe "hello" do
          map String.upcase()
        end

      assert result == %Just{value: "HELLO"}
    end

    test "zero-arity qualified calls work with Nothing cases" do
      result =
        maybe -5 do
          bind PipeTarget.check_positive()
        end

      assert result == %Nothing{}
    end
  end

  # ============================================================================
  # Module-Specific Options (opts parameter)
  # ============================================================================

  # Tests passing custom options to modules via {Module, opts} syntax with bind
  describe "module-specific options with bind" do
    test "passes options to module run/3 function" do
      result =
        maybe "FF" do
          bind {ParseIntWithBase, base: 16}
        end

      assert result == %Just{value: 255}
    end

    test "uses default when no options provided" do
      result =
        maybe "42" do
          bind ParseIntWithBase
        end

      assert result == %Just{value: 42}
    end

    test "different options for different modules in pipeline" do
      result =
        maybe "10" do
          bind {ParseIntWithBase, base: 10}
          bind {MinValidator, min: 5}
        end

      assert result == %Just{value: 10}
    end

    test "fails when option constraints not met" do
      result =
        maybe "5" do
          bind ParseIntWithBase
          bind {MinValidator, min: 10}
        end

      assert result == %Nothing{}
    end

    test "works with different number bases" do
      test_cases = [
        {16, "A5", 165, "hexadecimal"},
        {2, "1010", 10, "binary"},
        {8, "17", 15, "octal"}
      ]

      for {base, input, expected, name} <- test_cases do
        result =
          maybe input do
            bind {ParseIntWithBase, base: base}
          end

        assert result == %Just{value: expected},
               "Failed to parse #{input} as #{name} (base #{base})"
      end
    end

    test "complex pipeline with multiple module-specific options" do
      result =
        maybe "FF" do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 100}
        end

      assert result == %Just{value: 255}
    end
  end

  # Tests passing custom options to modules via {Module, opts} syntax with map
  describe "module-specific options with map" do
    test "passes options to module run/3 function" do
      result =
        maybe 10 do
          map {Multiplier, factor: 5}
        end

      assert result == %Just{value: 50}
    end

    test "uses default when no options provided" do
      result =
        maybe 10 do
          map Multiplier
        end

      assert result == %Just{value: 10}
    end

    test "multiple map operations with different options" do
      result =
        maybe 2 do
          map {Multiplier, factor: 3}
          map {Multiplier, factor: 4}
        end

      assert result == %Just{value: 24}
    end

    test "bind and map with options in same pipeline" do
      result =
        maybe "10" do
          bind {ParseIntWithBase, base: 10}
          bind {MinValidator, min: 5}
          map {Multiplier, factor: 10}
        end

      assert result == %Just{value: 100}
    end
  end

  # Tests module options edge cases
  describe "module-specific options - edge cases" do
    test "empty options list works" do
      result =
        maybe "42" do
          bind {ParseIntWithBase, []}
        end

      assert result == %Just{value: 42}
    end

    test "works with as: :raise return type" do
      result =
        maybe "A0", as: :raise do
          bind {ParseIntWithBase, base: 16}
        end

      assert result == 160
    end

    test "works with as: nil return type" do
      result =
        maybe "FF", as: nil do
          bind {ParseIntWithBase, base: 16}
          bind {MinValidator, min: 100}
        end

      assert result == 255
    end
  end

  # Tests that modules can be passed directly to Maybe functions
  describe "whitelisted Maybe functions" do
    test "allows or_else/2" do
      result =
        maybe nothing() do
          or_else fn -> just(42) end
        end

      assert result == %Just{value: 42}
    end

    test "allows tap/2 on Just" do
      test_pid = self()

      result =
        maybe 5 do
          map(&(&1 * 2))
          tap(fn x -> send(test_pid, {:tapped, x}) end)
          map(&(&1 + 1))
        end

      assert result == %Just{value: 11}
      assert_received {:tapped, 10}
    end

    test "allows tap/2 on Nothing" do
      result =
        maybe nothing() do
          tap(fn x -> send(self(), {:should_not_tap, x}) end)
        end

      assert result == %Nothing{}
      refute_received {:should_not_tap, _}
    end

    test "tap with bare module on Just" do
      test_pid = self()

      result =
        maybe 42 do
          tap {Logger, test_pid: test_pid, label: :logged_value}
          map(&(&1 * 2))
        end

      assert result == %Just{value: 84}
      assert_received {:logged_value, 42}
    end

    test "tap with bare module on Nothing" do
      result =
        maybe nothing() do
          tap {Logger, test_pid: self(), label: :should_not_log}
        end

      assert result == %Nothing{}
      refute_received {:should_not_log, _}
    end

    test "filter with bare module predicate (passes)" do
      result =
        maybe 5 do
          filter(IsPositive)
          map(&(&1 * 2))
        end

      assert result == %Just{value: 10}
    end

    test "filter with bare module predicate (fails)" do
      result =
        maybe -5 do
          filter(IsPositive)
          map(&(&1 * 2))
        end

      assert result == %Nothing{}
    end

    test "filter with module and options (passes)" do
      result =
        maybe 50 do
          filter({InRange, min: 0, max: 100})
          map(&(&1 * 2))
        end

      assert result == %Just{value: 100}
    end

    test "filter with module and options (fails)" do
      result =
        maybe 150 do
          filter({InRange, min: 0, max: 100})
          map(&(&1 * 2))
        end

      assert result == %Nothing{}
    end

    test "filter with module in complex pipeline" do
      result =
        maybe "42" do
          bind ParseInt
          filter(IsPositive)
          filter({InRange, min: 0, max: 100})
          map(&(&1 * 2))
        end

      assert result == %Just{value: 84}
    end
  end
end
