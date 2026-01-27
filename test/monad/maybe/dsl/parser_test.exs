defmodule Funx.Monad.Maybe.Dsl.ParserTest do
  @moduledoc """
  Unit tests for the Maybe DSL Parser.

  This file tests the compile-time AST parsing and transformation logic.
  It verifies:
  - Operation parsing (bind, map, ap, Maybe functions)
  - Auto-lifting transformations (Module.function() → fn x -> Module.function(x, ...) end)
  - Module alias expansion
  - Validator list validation
  - Compile-time error detection and messages

  For runtime execution behavior, see dsl_test.exs.
  """

  use ExUnit.Case, async: true

  alias Funx.Monad.Maybe.Dsl.Parser
  alias Funx.Monad.Maybe.Dsl.Step

  # Mock caller environment
  @env __ENV__

  # Test helpers
  defp parse_one(block) do
    [step] = Parser.parse_operations(block, @env, [])
    step
  end

  defp parse_all(block) do
    Parser.parse_operations(block, @env, [])
  end

  defp assert_type(step, type) do
    case type do
      :bind -> assert %Step.Bind{} = step
      :map -> assert %Step.Map{} = step
      :ap -> assert %Step.Ap{} = step
      :maybe_function -> assert %Step.MaybeFunction{} = step
      :protocol_function -> assert %Step.ProtocolFunction{} = step
    end
  end

  defp assert_compile_error(block, message) do
    error =
      assert_raise CompileError, fn ->
        Parser.parse_operations(block, @env, [])
      end

    assert error.description =~ message
    error
  end

  defp types(steps) do
    Enum.map(steps, fn
      %Step.Bind{} -> :bind
      %Step.Map{} -> :map
      %Step.Ap{} -> :ap
      %Step.MaybeFunction{} -> :maybe_function
      %Step.ProtocolFunction{} -> :protocol_function
    end)
  end

  # Tests basic operation parsing (bind, map, ap, multiple ops, options)
  describe "parse_operations/3" do
    test "parses single bind operation" do
      step = parse_one(quote do: bind(SomeModule))

      # Module is transformed to fn value -> SomeModule.bind(value, [], []) end
      assert %Step.Bind{operation: {:fn, _, _}, opts: []} = step
    end

    test "parses single map operation" do
      step = parse_one(quote do: map(SomeModule))

      # Module is transformed to fn value -> SomeModule.map(value, [], []) end
      assert %Step.Map{operation: {:fn, _, _}, opts: []} = step
    end

    test "parses single ap operation" do
      step = parse_one(quote do: ap(just(&(&1 + 1))))

      assert_type(step, :ap)
    end

    test "parses ap operation with module" do
      step = parse_one(quote do: ap(SomeModule))

      # Module is transformed to fn value -> SomeModule.ap(value, [], []) end
      assert %Step.Ap{applicative: {:fn, _, _}} = step
    end

    test "parses ap operation with module and options" do
      step = parse_one(quote do: ap({SomeModule, opt: :value}))

      # Module with options is transformed to fn value -> SomeModule.ap(value, [opt: :value], []) end
      assert %Step.Ap{applicative: {:fn, _, _}} = step
    end

    test "parses multiple operations in sequence" do
      block =
        quote do
          bind SomeModule
          map AnotherModule
          bind ThirdModule
        end

      [step1, step2, step3] = parse_all(block)

      # Modules are transformed to function calls
      assert %Step.Bind{operation: {:fn, _, _}} = step1
      assert %Step.Map{operation: {:fn, _, _}} = step2
      assert %Step.Bind{operation: {:fn, _, _}} = step3
    end

    test "parses operations with options" do
      step = parse_one(quote do: bind({SomeModule, [opt: :value]}))

      # Module with options is transformed to function call with options baked in
      assert %Step.Bind{operation: {:fn, _, _}, opts: []} = step
    end

    test "parses anonymous functions" do
      step = parse_one(quote do: bind(fn x -> {:ok, x} end))

      assert_type(step, :bind)
      assert is_function(step.operation) or match?({:fn, _, _}, step.operation)
    end

    test "parses function captures" do
      step = parse_one(quote do: map(&String.upcase/1))

      assert_type(step, :map)
    end
  end

  # Tests parsing of Maybe-specific functions (or_else, filter, filter_map, tap)
  describe "Maybe function operations" do
    # Table-driven tests for maybe_function operations
    @maybe_functions [:or_else]
    @protocol_functions [:tap, :filter, :filter_map]

    for func <- @maybe_functions do
      test "parses #{func} as maybe_function" do
        func_name = unquote(func)

        step =
          case func_name do
            :or_else -> parse_one(quote do: or_else(fn -> just(42) end))
          end

        assert %Step.MaybeFunction{function: ^func_name, args: _args} = step
      end
    end

    @protocol_function_steps %{
      tap: quote(do: tap(fn x -> x end)),
      filter: quote(do: filter(fn x -> x > 0 end)),
      filter_map: quote(do: filter_map(fn x -> if x > 0, do: just(x), else: nothing() end))
    }

    for func <- @protocol_functions do
      test "parses #{func} as protocol_function" do
        func_name = unquote(func)
        step = parse_one(@protocol_function_steps[func_name])
        assert %Step.ProtocolFunction{function: ^func_name, args: _args} = step
      end
    end

    test "parses tap with module and options" do
      step = parse_one(quote do: tap({SomeModule, opt: :value}))

      assert %Step.ProtocolFunction{function: :tap, protocol: Funx.Tappable, args: _args} = step
    end

    test "parses or_else with module and options" do
      step = parse_one(quote do: or_else({DefaultModule, default: 42}))

      assert %Step.MaybeFunction{function: :or_else, args: _args} = step
    end

    test "parses tap with bare module" do
      step = parse_one(quote do: tap(SomeModule))

      assert %Step.ProtocolFunction{function: :tap, protocol: Funx.Tappable, args: _args} = step
    end

    test "parses filter with Filterable protocol" do
      step = parse_one(quote do: filter(fn x -> x > 0 end))

      assert %Step.ProtocolFunction{function: :filter, protocol: Funx.Filterable, args: _args} =
               step
    end
  end

  # Tests AST transformations for auto-lifting function calls to unary form
  describe "auto-lifting transformations" do
    test "lifts Module.function() zero-arity calls to &Module.function/1" do
      step = parse_one(quote do: bind(String.upcase()))

      assert_type(step, :bind)
      assert match?({:&, _, _}, step.operation)
    end

    test "lifts Module.function(arg) calls to fn x -> Module.function(x, arg) end" do
      step = parse_one(quote do: bind(String.pad_leading(5, "0")))

      assert_type(step, :bind)
      assert match?({:fn, _, _}, step.operation)
    end

    test "lifts bare function calls fun(args) to fn x -> fun(x, args) end" do
      step = parse_one(quote do: bind(some_function(42)))

      assert_type(step, :bind)
      assert match?({:fn, _, _}, step.operation)
    end

    test "lifts zero-arity bare function calls to &fun/1" do
      step = parse_one(quote do: map(some_function()))

      assert_type(step, :map)
      assert match?({:&, _, _}, step.operation)
    end

    test "does not lift anonymous functions" do
      step = parse_one(quote do: bind(fn x -> {:ok, x * 2} end))

      assert_type(step, :bind)
      assert match?({:fn, _, _}, step.operation)
    end

    test "does not lift function captures" do
      step = parse_one(quote do: map(&(&1 * 2)))

      assert_type(step, :map)
      assert match?({:&, _, _}, step.operation)
    end
  end

  # Tests transformation of module aliases
  describe "module alias expansion" do
    test "transforms module aliases to behavior method calls" do
      step = parse_one(quote do: bind(String))

      # Module is transformed to fn value -> String.bind(value, [], []) end
      assert %Step.Bind{operation: {:fn, _, _}} = step
    end

    test "transforms nested module aliases" do
      step = parse_one(quote do: bind(Funx.Monad.Maybe))

      # Module is transformed to fn value -> Funx.Monad.Maybe.bind(value, [], []) end
      assert %Step.Bind{operation: {:fn, _, _}} = step
    end
  end

  # Tests compile-time error detection and helpful error messages
  describe "error handling" do
    test "raises CompileError for invalid operation like atom literal" do
      assert_compile_error(quote(do: :some_atom), "Invalid operation")
    end

    test "raises CompileError for number literal" do
      assert_compile_error(quote(do: 123), "Invalid operation")
    end

    test "raises CompileError for unknown Maybe function" do
      assert_compile_error(quote(do: unknown_function()), "Invalid operation: unknown_function")
    end

    test "raises CompileError with helpful message for unknown function" do
      error =
        assert_compile_error(
          quote(do: custom_function(42)),
          "Bare function calls are not allowed"
        )

      assert error.description =~ "bind custom_function(...)"
      assert error.description =~ "map custom_function(...)"
    end

    test "error message lists allowed Maybe functions" do
      error = assert_compile_error(quote(do: not_a_function()), "Bare function calls")

      assert error.description =~ "or_else"
      assert error.description =~ "filter"
      assert error.description =~ "tap"
    end

    test "raises CompileError for bare module alias in pipeline" do
      module_alias = {:__aliases__, [line: 1], [:"Elixir", :SomeModule]}

      assert_compile_error(module_alias, "Modules must be used with a keyword")
    end
  end

  # Note: Maybe DSL's filter operation takes a single predicate, not a list.
  # Validator list validation only applies to Either DSL's validate operation.

  # Tests {Module, opts} syntax for bind/map operations
  describe "operation with options syntax" do
    test "parses {Module, opts} tuple for bind" do
      block = quote do: bind({ParseInt, base: 16})
      step = parse_one(block)

      # Module with opts is transformed to fn value -> ParseInt.bind(value, [base: 16], []) end
      # Options are baked into the function, not stored in opts field
      assert %Step.Bind{operation: {:fn, _, _}, opts: []} = step
    end

    test "parses {Module, opts} tuple for map" do
      block = quote do: map({Multiplier, factor: 5})
      step = parse_one(block)

      # Module with opts is transformed to fn value -> Multiplier.map(value, [factor: 5], []) end
      # Options are baked into the function, not stored in opts field
      assert %Step.Map{operation: {:fn, _, _}, opts: []} = step
    end

    test "handles empty options list" do
      block = quote do: bind({SomeModule, []})
      step = parse_one(block)

      # Module with empty opts is transformed to fn value -> SomeModule.bind(value, [], []) end
      assert %Step.Bind{operation: {:fn, _, _}, opts: []} = step
    end

    test "handles multiple options" do
      block = quote do: bind({SomeModule, [opt1: :val1, opt2: :val2, opt3: :val3]})
      step = parse_one(block)

      # Multiple options are baked into the function
      assert %Step.Bind{operation: {:fn, _, _}, opts: []} = step
    end
  end

  # Tests parsing of complete pipelines with mixed operation types
  describe "complex parsing scenarios" do
    test "parses pipeline with all operation types" do
      block =
        quote do
          bind ParseInt
          map Double
          filter(&(&1 > 0))
          or_else(fn -> just(0) end)
          tap(fn x -> x end)
        end

      steps = parse_all(block)

      assert length(steps) == 5

      assert types(steps) == [
               :bind,
               :map,
               :protocol_function,
               :maybe_function,
               :protocol_function
             ]
    end

    test "parses pipeline with mixed syntax forms" do
      block =
        quote do
          bind ParseInt
          bind {ParseIntWithBase, base: 16}
          map fn x -> x * 2 end
          map &String.upcase/1
          map String.pad_leading(5, "0")
        end

      steps = parse_all(block)

      assert length(steps) == 5
      assert types(steps) == [:bind, :bind, :map, :map, :map]
    end
  end
end
