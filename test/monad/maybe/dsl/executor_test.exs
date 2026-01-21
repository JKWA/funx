defmodule Funx.Monad.Maybe.Dsl.ExecutorTest do
  @moduledoc """
  Unit tests for the Maybe DSL Executor.

  Tests the runtime execution engine in isolation, focusing on:
  - Input lifting (various types → Maybe)
  - Result normalization (tuples/Maybe → Maybe)
  - Result wrapping (Maybe → :raise/:nil/:maybe)

  For end-to-end pipeline execution, see dsl_test.exs.
  """

  use ExUnit.Case, async: true
  use Funx.Monad.Maybe
  use Funx.Monad.Either

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.Dsl.Executor

  # Tests input lifting for various input types
  describe "lift_input/1" do
    test "lifts plain value to Just" do
      assert Executor.lift_input(42) == just(42)
    end

    test "passes through Just unchanged" do
      input = just(42)
      assert Executor.lift_input(input) == input
    end

    test "passes through Nothing unchanged" do
      input = nothing()
      assert Executor.lift_input(input) == input
    end

    test "converts {:ok, value} to Just" do
      assert Executor.lift_input({:ok, 42}) == just(42)
    end

    test "converts {:error, reason} to Nothing" do
      assert Executor.lift_input({:error, "failed"}) == nothing()
    end

    test "lifts nil to Nothing" do
      assert Executor.lift_input(nil) == nothing()
    end

    test "lifts Either.Right to Just" do
      assert Executor.lift_input(Either.right(42)) == just(42)
    end

    test "lifts Either.Left to Nothing" do
      assert Executor.lift_input(Either.left("error")) == nothing()
    end

    test "lifts complex data structures" do
      data = %{name: "Alice", age: 30}
      assert Executor.lift_input(data) == just(data)
    end
  end

  # Tests normalization of module run/3 results
  describe "normalize_run_result/1" do
    test "converts {:ok, value} to Just" do
      assert Executor.normalize_run_result({:ok, 42}) == just(42)
    end

    test "converts {:error, reason} to Nothing" do
      assert Executor.normalize_run_result({:error, "failed"}) == nothing()
    end

    test "passes through Just unchanged" do
      maybe = just(42)
      assert Executor.normalize_run_result(maybe) == maybe
    end

    test "passes through Nothing unchanged" do
      maybe = nothing()
      assert Executor.normalize_run_result(maybe) == maybe
    end

    test "converts Either Right to Just" do
      assert Executor.normalize_run_result(Either.right(42)) == just(42)
    end

    test "converts Either Left to Nothing" do
      assert Executor.normalize_run_result(Either.left("error")) == nothing()
    end

    test "converts nil to Nothing" do
      assert Executor.normalize_run_result(nil) == nothing()
    end

    test "raises ArgumentError for invalid return value" do
      assert_raise ArgumentError, ~r/bind\/3, map\/3, or predicate\/3 callback must return/, fn ->
        Executor.normalize_run_result(:invalid)
      end
    end

    test "raises ArgumentError for plain value" do
      assert_raise ArgumentError, ~r/bind\/3, map\/3, or predicate\/3 callback must return/, fn ->
        Executor.normalize_run_result(42)
      end
    end

    test "raises ArgumentError for list" do
      assert_raise ArgumentError, ~r/bind\/3, map\/3, or predicate\/3 callback must return/, fn ->
        Executor.normalize_run_result([1, 2, 3])
      end
    end

    test "includes operation type in error message when provided" do
      error =
        assert_raise ArgumentError, fn ->
          Executor.normalize_run_result(:invalid, nil, "bind")
        end

      assert error.message =~ "in bind operation"
    end

    test "includes line and column in error message when metadata provided" do
      meta = %{line: 42, column: 10}

      error =
        assert_raise ArgumentError, fn ->
          Executor.normalize_run_result(:invalid, meta, "map")
        end

      assert error.message =~ "at line 42, column 10"
    end

    test "includes only line in error message when column not available" do
      meta = %{line: 99, column: nil}

      error =
        assert_raise ArgumentError, fn ->
          Executor.normalize_run_result(:invalid, meta)
        end

      assert error.message =~ "at line 99"
      refute error.message =~ "column"
    end

    test "handles metadata without location info" do
      meta = %{some_other_key: "value"}

      error =
        assert_raise ArgumentError, fn ->
          Executor.normalize_run_result(:invalid, meta)
        end

      # Should not crash, just omit location
      refute error.message =~ "at line"
    end
  end

  # Tests result wrapping for different return types
  describe "wrap_result/2" do
    test "as: :maybe passes through Just" do
      maybe = just(42)
      assert Executor.wrap_result(maybe, :maybe) == maybe
    end

    test "as: :maybe passes through Nothing" do
      maybe = nothing()
      assert Executor.wrap_result(maybe, :maybe) == maybe
    end

    test "as: :maybe raises for non-Maybe value" do
      assert_raise ArgumentError, ~r/Expected Maybe struct/, fn ->
        Executor.wrap_result(42, :maybe)
      end
    end

    test "as: :raise returns value on Just" do
      assert Executor.wrap_result(just(42), :raise) == 42
    end

    test "as: :raise raises on Nothing" do
      assert_raise RuntimeError, "Nothing value encountered", fn ->
        Executor.wrap_result(nothing(), :raise)
      end
    end

    test "as: :nil returns value on Just" do
      assert Executor.wrap_result(just(42), nil) == 42
    end

    test "as: :nil returns nil on Nothing" do
      assert Executor.wrap_result(nothing(), nil) == nil
    end
  end
end
