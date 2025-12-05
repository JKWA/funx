defmodule Funx.Monad.Either.Dsl.Transformers.OptimizeConsecutiveTapsTest do
  @moduledoc """
  Unit tests for the OptimizeConsecutiveTaps transformer.

  Tests the optimization logic in isolation.
  """

  use ExUnit.Case, async: true

  alias Funx.Monad.Either.Dsl.Step
  alias Funx.Monad.Either.Dsl.Transformers.OptimizeConsecutiveTaps

  describe "transform/2" do
    test "returns {:ok, steps} tuple" do
      steps = [%Step.Bind{operation: String, opts: []}]
      assert {:ok, _} = OptimizeConsecutiveTaps.transform(steps, [])
    end

    test "leaves single tap unchanged" do
      steps = [
        %Step.Bind{operation: String, opts: []},
        %Step.EitherFunction{function: :tap, args: [fn x -> x end]},
        %Step.Map{operation: String, opts: []}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 3
      assert Enum.at(result, 1).function == :tap
    end

    test "removes consecutive taps, keeping only the last" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> send(self(), {:tap1, x}) end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> send(self(), {:tap2, x}) end]}
      tap3 = %Step.EitherFunction{function: :tap, args: [fn x -> send(self(), {:tap3, x}) end]}

      steps = [
        %Step.Bind{operation: String, opts: []},
        tap1,
        tap2,
        tap3,
        %Step.Map{operation: String, opts: []}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 3

      # Should have bind, last tap, map
      assert match?(%Step.Bind{}, Enum.at(result, 0))
      assert match?(%Step.EitherFunction{function: :tap}, Enum.at(result, 1))
      assert match?(%Step.Map{}, Enum.at(result, 2))

      # Verify it's the last tap (tap3)
      assert Enum.at(result, 1) == tap3
    end

    test "handles two consecutive taps" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x + 1 end]}

      steps = [tap1, tap2]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 1
      assert hd(result) == tap2
    end

    test "preserves taps separated by other operations" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}

      steps = [
        tap1,
        %Step.Map{operation: String, opts: []},
        tap2
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 3

      # Both taps should be preserved because they're separated
      assert match?(%Step.EitherFunction{function: :tap}, Enum.at(result, 0))
      assert match?(%Step.Map{}, Enum.at(result, 1))
      assert match?(%Step.EitherFunction{function: :tap}, Enum.at(result, 2))
    end

    test "handles pipeline starting with consecutive taps" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}

      steps = [
        tap1,
        tap2,
        %Step.Bind{operation: String, opts: []}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 2
      assert Enum.at(result, 0) == tap2
      assert match?(%Step.Bind{}, Enum.at(result, 1))
    end

    test "handles pipeline ending with consecutive taps" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}

      steps = [
        %Step.Bind{operation: String, opts: []},
        tap1,
        tap2
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 2
      assert match?(%Step.Bind{}, Enum.at(result, 0))
      assert Enum.at(result, 1) == tap2
    end

    test "handles pipeline with only taps" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap3 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}

      steps = [tap1, tap2, tap3]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 1
      assert hd(result) == tap3
    end

    test "handles empty pipeline" do
      steps = []

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert result == []
    end

    test "handles pipeline with no taps" do
      steps = [
        %Step.Bind{operation: String, opts: []},
        %Step.Map{operation: String, opts: []},
        %Step.EitherFunction{function: :or_else, args: [fn -> 42 end]}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert result == steps
    end

    test "preserves other EitherFunction types" do
      steps = [
        %Step.EitherFunction{function: :or_else, args: [fn -> 42 end]},
        %Step.EitherFunction{function: :tap, args: [fn x -> x end]},
        %Step.EitherFunction{function: :map_left, args: [fn e -> e end]},
        %Step.EitherFunction{function: :filter_or_else, args: [fn x -> x > 0 end, fn -> "error" end]}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      # All non-tap operations should be preserved
      assert length(result) == 4
    end

    test "handles multiple groups of consecutive taps" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x + 1 end]}
      tap3 = %Step.EitherFunction{function: :tap, args: [fn x -> x + 2 end]}
      tap4 = %Step.EitherFunction{function: :tap, args: [fn x -> x + 3 end]}

      steps = [
        %Step.Bind{operation: String, opts: []},
        tap1,
        tap2,
        %Step.Map{operation: String, opts: []},
        tap3,
        tap4,
        %Step.Bind{operation: String, opts: []}
      ]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 5

      # Should have: bind, tap2 (last of first group), map, tap4 (last of second group), bind
      assert match?(%Step.Bind{}, Enum.at(result, 0))
      assert Enum.at(result, 1) == tap2
      assert match?(%Step.Map{}, Enum.at(result, 2))
      assert Enum.at(result, 3) == tap4
      assert match?(%Step.Bind{}, Enum.at(result, 4))
    end

    test "preserves step metadata" do
      tap1 = %Step.EitherFunction{
        function: :tap,
        args: [fn x -> x end],
        __meta__: %{line: 10, column: 5}
      }

      tap2 = %Step.EitherFunction{
        function: :tap,
        args: [fn x -> x end],
        __meta__: %{line: 11, column: 5}
      }

      steps = [tap1, tap2]

      assert {:ok, result} = OptimizeConsecutiveTaps.transform(steps, [])
      assert length(result) == 1

      # Metadata from the last tap should be preserved
      assert hd(result).__meta__ == %{line: 11, column: 5}
    end

    test "ignores opts parameter" do
      tap1 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}
      tap2 = %Step.EitherFunction{function: :tap, args: [fn x -> x end]}

      steps = [tap1, tap2]

      # Opts should be ignored
      assert {:ok, result1} = OptimizeConsecutiveTaps.transform(steps, [])
      assert {:ok, result2} = OptimizeConsecutiveTaps.transform(steps, [some: :option])

      assert result1 == result2
    end
  end
end
