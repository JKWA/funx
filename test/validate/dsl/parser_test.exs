defmodule Funx.Validate.Dsl.ParserTest do
  @moduledoc """
  Unit tests for the Validate DSL Parser, specifically focusing on
  compile-time validation of validator specs.
  """
  use ExUnit.Case, async: true

  alias Funx.Validate.Dsl.Parser

  describe "parse_steps/2 with valid validator specs" do
    test "accepts module alias as validator" do
      ast =
        quote do
          at :name, Required
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts tuple with module and options" do
      ast =
        quote do
          at :name, {MinLength, min: 3}
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts list of validators" do
      ast =
        quote do
          at :name, [Required, Email]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts function capture" do
      ast =
        quote do
          at :name, &String.upcase/1
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts anonymous function" do
      ast =
        quote do
          at :name, fn x -> x end
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts function call" do
      ast =
        quote do
          at :name, my_validator()
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts qualified function call" do
      ast =
        quote do
          at :name, MyModule.validator()
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts variable reference" do
      ast =
        quote do
          at :name, my_var
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts multiple validators in a list" do
      ast =
        quote do
          at :name, [Required, {MinLength, min: 3}, Email]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end
  end

  describe "parse_steps/2 rejects invalid validator specs" do
    test "rejects literal number" do
      ast =
        quote do
          at :name, 123
        end

      assert_raise CompileError, ~r/Invalid validator: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal float" do
      ast =
        quote do
          at :name, 3.14
        end

      assert_raise CompileError, ~r/Invalid validator: 3.14/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal string" do
      ast =
        quote do
          at :name, "validator"
        end

      assert_raise CompileError, ~r/Invalid validator: "validator"/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal atom" do
      ast =
        quote do
          at :name, :atom
        end

      assert_raise CompileError, ~r/Invalid validator: :atom/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects empty list" do
      ast =
        quote do
          at :name, []
        end

      assert_raise CompileError, ~r/Invalid validator: empty list/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end
  end

  describe "parse_steps/2 with bare validators (root validators)" do
    test "accepts module alias as bare validator" do
      ast =
        quote do
          MyValidator
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "accepts function capture as bare validator" do
      ast =
        quote do
          &String.upcase/1
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "rejects literal number as bare validator" do
      ast =
        quote do
          123
        end

      assert_raise CompileError, ~r/Invalid validator: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal string as bare validator" do
      ast =
        quote do
          "validator"
        end

      assert_raise CompileError, ~r/Invalid validator: "validator"/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end
  end

  describe "parse_steps/2 with validator lists" do
    test "rejects literal number in validator list" do
      ast =
        quote do
          at :name, [Required, 123]
        end

      assert_raise CompileError, ~r/Invalid validator in list: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal string in validator list" do
      ast =
        quote do
          at :name, [Required, "bad"]
        end

      assert_raise CompileError, ~r/Invalid validator in list: "bad"/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects literal atom in validator list" do
      ast =
        quote do
          at :name, [Required, :bad]
        end

      assert_raise CompileError, ~r/Invalid validator in list: :bad/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "rejects nested list in validator list" do
      ast =
        quote do
          at :name, [Required, [Email]]
        end

      assert_raise CompileError, ~r/Invalid validator in list:/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "allows module aliases in list" do
      ast =
        quote do
          at :name, [Required, Email, MinLength]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "allows tuples with options in list" do
      ast =
        quote do
          at :name, [Required, {MinLength, min: 3}, {MaxLength, max: 10}]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "allows function captures in list" do
      ast =
        quote do
          at :name, [Required, &String.upcase/1]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "allows anonymous functions in list" do
      ast =
        quote do
          at :name, [Required, fn x -> x end]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "allows function calls in list" do
      ast =
        quote do
          at :name, [Required, my_validator()]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "allows qualified function calls in list" do
      ast =
        quote do
          at :name, [Required, MyModule.validator()]
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end
  end

  describe "parse_steps/2 with multiple statements" do
    test "validates all statements in block" do
      ast =
        quote do
          at :name, Required
          at :email, Email
          at :age, Positive
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 3
    end

    test "fails on first invalid statement" do
      ast =
        quote do
          at :name, Required
          at :email, 123
          at :age, Positive
        end

      assert_raise CompileError, ~r/Invalid validator: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "validates bare validators mixed with at statements" do
      ast =
        quote do
          RootValidator
          at :name, Required
          AnotherRootValidator
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 3
    end

    test "fails on invalid bare validator in mixed block" do
      ast =
        quote do
          RootValidator
          123
          at :name, Required
        end

      assert_raise CompileError, ~r/Invalid validator: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end
  end

  describe "parse_steps/2 edge cases" do
    test "handles tuple with module and options where module is a variable" do
      ast =
        quote do
          at :name, {validator_var, min: 3}
        end

      # Should not raise - variables are allowed
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "handles tuple with function call and options" do
      ast =
        quote do
          at :name, {my_validator(), min: 3}
        end

      # Should not raise
      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end

    test "rejects tuple with literal and options" do
      ast =
        quote do
          at :name, {123, min: 3}
        end

      assert_raise CompileError, ~r/Invalid validator: 123/, fn ->
        Parser.parse_steps(ast, __ENV__)
      end
    end

    test "handles single statement (not a block)" do
      # When there's only one statement, it's not wrapped in __block__
      ast =
        quote do
          at :name, Required
        end

      steps = Parser.parse_steps(ast, __ENV__)
      assert length(steps) == 1
    end
  end
end
