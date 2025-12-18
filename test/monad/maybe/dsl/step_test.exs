defmodule Funx.Monad.Maybe.Dsl.StepTest do
  @moduledoc """
  Unit tests for the Maybe DSL Step types.

  Tests the Step struct types following Spark's Entity pattern:
  - Struct creation and field validation
  - Enforced keys
  - Metadata handling
  - Type unions
  """

  use ExUnit.Case, async: true

  alias Funx.Monad.Maybe.Dsl.Step

  describe "Step.Bind" do
    test "creates struct with required operation field" do
      step = %Step.Bind{operation: String}

      assert step.operation == String
      assert step.opts == []
      assert step.__meta__ == nil
    end

    test "creates struct with opts and metadata" do
      meta = %{line: 42, column: 10}
      step = %Step.Bind{operation: &String.upcase/1, opts: [trim: true], __meta__: meta}

      assert is_function(step.operation)
      assert step.opts == [trim: true]
      assert step.__meta__ == meta
    end

    test "enforces operation key" do
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(Step.Bind, opts: [])
      end
    end
  end

  describe "Step.Map" do
    test "creates struct with required operation field" do
      step = %Step.Map{operation: String}

      assert step.operation == String
      assert step.opts == []
      assert step.__meta__ == nil
    end

    test "creates struct with opts and metadata" do
      meta = %{line: 99}
      step = %Step.Map{operation: fn x -> x * 2 end, opts: [factor: 2], __meta__: meta}

      assert is_function(step.operation)
      assert step.opts == [factor: 2]
      assert step.__meta__ == meta
    end

    test "enforces operation key" do
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(Step.Map, opts: [])
      end
    end
  end

  describe "Step.Ap" do
    test "creates struct with required applicative field" do
      step = %Step.Ap{applicative: &(&1 + 1)}

      assert is_function(step.applicative)
      assert step.__meta__ == nil
    end

    test "creates struct with metadata" do
      meta = %{line: 10, column: 5}
      step = %Step.Ap{applicative: fn x -> x * 2 end, __meta__: meta}

      assert is_function(step.applicative)
      assert step.__meta__ == meta
    end

    test "enforces applicative key" do
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(Step.Ap, __meta__: nil)
      end
    end
  end

  describe "Step.MaybeFunction" do
    test "creates struct with required function and args fields" do
      step = %Step.MaybeFunction{function: :or_else, args: [fn -> 42 end]}

      assert step.function == :or_else
      assert is_list(step.args)
      assert step.__meta__ == nil
    end

    test "creates struct with metadata" do
      meta = %{line: 25}
      step = %Step.MaybeFunction{function: :or_else, args: [fn -> 42 end], __meta__: meta}

      assert step.function == :or_else
      assert length(step.args) == 1
      assert step.__meta__ == meta
    end

    test "enforces function and args keys" do
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(Step.MaybeFunction, __meta__: nil)
      end
    end
  end

  describe "Step.ProtocolFunction" do
    test "creates struct with required protocol, function and args fields" do
      step = %Step.ProtocolFunction{
        protocol: Funx.Tappable,
        function: :tap,
        args: [fn x -> x end]
      }

      assert step.protocol == Funx.Tappable
      assert step.function == :tap
      assert is_list(step.args)
      assert step.__meta__ == nil
    end

    test "creates struct with metadata" do
      meta = %{line: 50, column: 3}

      step = %Step.ProtocolFunction{
        protocol: Funx.Filterable,
        function: :filter,
        args: [],
        __meta__: meta
      }

      assert step.protocol == Funx.Filterable
      assert step.function == :filter
      assert step.args == []
      assert step.__meta__ == meta
    end

    test "enforces protocol, function and args keys" do
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(Step.ProtocolFunction, __meta__: nil)
      end
    end
  end

  describe "Step type union" do
    test "Bind matches Step.t() type" do
      step = %Step.Bind{operation: String}
      assert %Step.Bind{} = step
    end

    test "Map matches Step.t() type" do
      step = %Step.Map{operation: String}
      assert %Step.Map{} = step
    end

    test "Ap matches Step.t() type" do
      step = %Step.Ap{applicative: &(&1 + 1)}
      assert %Step.Ap{} = step
    end

    test "MaybeFunction matches Step.t() type" do
      step = %Step.MaybeFunction{function: :or_else, args: []}
      assert %Step.MaybeFunction{} = step
    end

    test "ProtocolFunction matches Step.t() type" do
      step = %Step.ProtocolFunction{protocol: Funx.Tappable, function: :tap, args: []}
      assert %Step.ProtocolFunction{} = step
    end
  end

  describe "metadata handling" do
    test "metadata can be nil" do
      step = %Step.Bind{operation: String, __meta__: nil}
      assert step.__meta__ == nil
    end

    test "metadata can be a map with line and column" do
      meta = %{line: 42, column: 10}
      step = %Step.Map{operation: String, __meta__: meta}

      assert step.__meta__.line == 42
      assert step.__meta__.column == 10
    end

    test "metadata can have only line" do
      meta = %{line: 99, column: nil}
      step = %Step.Ap{applicative: &(&1 + 1), __meta__: meta}

      assert step.__meta__.line == 99
      assert step.__meta__.column == nil
    end

    test "metadata can have arbitrary fields" do
      meta = %{line: 1, column: 1, custom: "data"}
      step = %Step.MaybeFunction{function: :or_else, args: [], __meta__: meta}

      assert step.__meta__.line == 1
      assert step.__meta__.custom == "data"
    end
  end
end
