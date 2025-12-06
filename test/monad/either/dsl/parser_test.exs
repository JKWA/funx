defmodule Funx.Monad.Either.Dsl.ParserTest do
  @moduledoc """
  Unit tests for the Either DSL Parser.

  This file tests the compile-time AST parsing and transformation logic.
  It verifies:
  - Operation parsing (bind, map, ap, Either functions)
  - Auto-lifting transformations (Module.function() → fn x -> Module.function(x, ...) end)
  - Module alias expansion
  - Validator list validation
  - Compile-time error detection and messages

  For runtime execution behavior, see dsl_test.exs.
  """

  use ExUnit.Case, async: true

  alias Funx.Monad.Either.Dsl.Parser
  alias Funx.Monad.Either.Dsl.Step

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
      :either_function -> assert %Step.EitherFunction{} = step
      :bindable_function -> assert %Step.BindableFunction{} = step
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
      %Step.EitherFunction{} -> :either_function
      %Step.BindableFunction{} -> :bindable_function
    end)
  end

  # Tests basic operation parsing (bind, map, ap, multiple ops, options)
  describe "parse_operations/3" do
    test "parses single bind operation" do
      step = parse_one(quote do: bind(SomeModule))

      assert %Step.Bind{operation: SomeModule, opts: []} = step
    end

    test "parses single map operation" do
      step = parse_one(quote do: map(SomeModule))

      assert %Step.Map{operation: SomeModule, opts: []} = step
    end

    test "parses single ap operation" do
      step = parse_one(quote do: ap(right(&(&1 + 1))))

      assert_type(step, :ap)
    end

    test "parses multiple operations in sequence" do
      block =
        quote do
          bind SomeModule
          map AnotherModule
          bind ThirdModule
        end

      [step1, step2, step3] = parse_all(block)

      assert %Step.Bind{operation: SomeModule} = step1
      assert %Step.Map{operation: AnotherModule} = step2
      assert %Step.Bind{operation: ThirdModule} = step3
    end

    test "parses operations with options" do
      step = parse_one(quote do: bind({SomeModule, [opt: :value]}))

      assert %Step.Bind{operation: SomeModule, opts: [opt: :value]} = step
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

  # Tests parsing of Either-specific functions (filter_or_else, or_else, map_left, flip, tap, validate)
  describe "Either function operations" do
    # Table-driven tests for either_function operations
    @either_functions [:filter_or_else, :or_else, :map_left, :flip, :tap]

    for func <- @either_functions do
      test "parses #{func} as either_function" do
        func_name = unquote(func)

        step =
          case func_name do
            :filter_or_else -> parse_one(quote do: filter_or_else(&(&1 > 0), fn -> "error" end))
            :or_else -> parse_one(quote do: or_else(fn -> right(42) end))
            :map_left -> parse_one(quote do: map_left(fn e -> "Error: #{e}" end))
            :flip -> parse_one(quote do: flip())
            :tap -> parse_one(quote do: tap(fn x -> x end))
          end

        assert %Step.EitherFunction{function: ^func_name, args: _args} = step
      end
    end

    test "parses validate as bindable_function" do
      step = parse_one(quote do: validate([SomeValidator]))

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "parses tap with module and options" do
      step = parse_one(quote do: tap({SomeModule, opt: :value}))

      assert %Step.EitherFunction{function: :tap, args: _args} = step
    end

    test "parses or_else with module and options" do
      step = parse_one(quote do: or_else({DefaultModule, default: 42}))

      assert %Step.EitherFunction{function: :or_else, args: _args} = step
    end

    test "parses tap with bare module" do
      step = parse_one(quote do: tap(SomeModule))

      assert %Step.EitherFunction{function: :tap, args: _args} = step
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

  # Tests expansion of module aliases to full atoms at compile time
  describe "module alias expansion" do
    test "expands module aliases to atoms" do
      step = parse_one(quote do: bind(String))

      assert %Step.Bind{operation: String} = step
      assert is_atom(step.operation)
    end

    test "expands nested module aliases" do
      step = parse_one(quote do: bind(Funx.Monad.Either))

      assert %Step.Bind{operation: Funx.Monad.Either} = step
      assert is_atom(step.operation)
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

    test "raises CompileError for unknown Either function" do
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

    test "error message lists allowed Either functions" do
      error = assert_compile_error(quote(do: not_a_function()), "Bare function calls")

      assert error.description =~ "validate"
      assert error.description =~ "filter_or_else"
      assert error.description =~ "tap"
    end

    test "raises CompileError for bare module alias in pipeline" do
      module_alias = {:__aliases__, [line: 1], [:"Elixir", :SomeModule]}

      assert_compile_error(module_alias, "Modules must be used with a keyword")
    end
  end

  # Tests validation of validator lists (reject literals, accept functions/modules)
  describe "validator list validation" do
    test "rejects number literals in validator lists" do
      assert_compile_error(quote(do: validate([1, 2, 3])), "Invalid validator in list")
    end

    test "rejects string literals in validator lists" do
      assert_compile_error(quote(do: validate(["not", "valid"])), "Invalid validator in list")
    end

    test "rejects map literals in validator lists" do
      assert_compile_error(quote(do: validate([%{key: :value}])), "Invalid validator in list")
    end

    test "rejects atom literals in validator lists" do
      assert_compile_error(quote(do: validate([:atom])), "Invalid validator in list")
    end

    test "accepts modules in validator lists" do
      block = quote do: validate([SomeValidator, AnotherValidator])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts {Module, opts} tuples in validator lists" do
      block = quote do: validate([{SomeValidator, opt: :value}])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts function captures in validator lists" do
      block = quote do: validate([&positive?/1])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts anonymous functions in validator lists" do
      block = quote do: validate([fn x -> x > 0 end])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts function calls in validator lists" do
      block = quote do: validate([Validator.positive?()])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts variables in validator lists" do
      # Variables are AST nodes like {name, meta, context}
      block = quote do: validate([validator_var])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "accepts other valid AST nodes in validator lists" do
      # Test the catch-all clause that allows other AST nodes
      # This could be things like case expressions, with statements, etc.
      # We'll use a simple tuple AST that doesn't match other patterns
      block =
        quote do
          validate([
            case x do
              _ -> true
            end
          ])
        end

      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: _args} = step
    end

    test "rejects empty list literals in validator lists" do
      assert_compile_error(quote(do: validate([[]])), "Invalid validator in list")
    end

    test "rejects non-empty list literals in validator lists" do
      assert_compile_error(quote(do: validate([[1, 2, 3]])), "Invalid validator in list")
    end
  end

  # Tests transformation of bare modules and {Module, opts} in function arguments
  describe "module transformation in arguments" do
    test "transforms bare module to function call" do
      block = quote do: validate([SomeValidator])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: [validators]} = step
      # Should be transformed to list of functions
      assert is_list(validators)
    end

    test "transforms {Module, opts} to function call with options" do
      block = quote do: validate([{SomeValidator, min: 0, max: 100}])
      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: [validators]} = step
      assert is_list(validators)
    end

    test "transforms mixed list of validators" do
      block =
        quote do
          validate([
            SomeValidator,
            {AnotherValidator, opt: :value},
            &third_validator/1,
            fn x -> x > 0 end
          ])
        end

      step = parse_one(block)

      assert %Step.BindableFunction{function: :validate, args: [validators]} = step
      assert is_list(validators)
      assert length(validators) == 4
    end
  end

  # Tests {Module, opts} syntax for bind/map operations
  describe "operation with options syntax" do
    test "parses {Module, opts} tuple for bind" do
      block = quote do: bind({ParseInt, base: 16})
      step = parse_one(block)

      assert %Step.Bind{operation: ParseInt, opts: [base: 16]} = step
    end

    test "parses {Module, opts} tuple for map" do
      block = quote do: map({Multiplier, factor: 5})
      step = parse_one(block)

      assert %Step.Map{operation: Multiplier, opts: [factor: 5]} = step
    end

    test "handles empty options list" do
      block = quote do: bind({SomeModule, []})
      step = parse_one(block)

      assert %Step.Bind{operation: SomeModule, opts: []} = step
    end

    test "handles multiple options" do
      block = quote do: bind({SomeModule, [opt1: :val1, opt2: :val2, opt3: :val3]})
      step = parse_one(block)

      assert %Step.Bind{operation: SomeModule, opts: [opt1: :val1, opt2: :val2, opt3: :val3]} =
               step
    end
  end

  # Tests parsing of complete pipelines with mixed operation types
  describe "complex parsing scenarios" do
    test "parses pipeline with all operation types" do
      block =
        quote do
          bind ParseInt
          map Double
          validate [PositiveNumber]
          filter_or_else(&(&1 < 100), fn -> "too large" end)
          map_left(fn e -> "Error: #{e}" end)
          tap(fn x -> x end)
        end

      steps = parse_all(block)

      assert length(steps) == 6

      assert types(steps) == [
               :bind,
               :map,
               :bindable_function,
               :either_function,
               :either_function,
               :either_function
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
