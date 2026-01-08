defmodule Funx.Monad.Either.Dsl.ExecutorTest do
  @moduledoc """
  Unit tests for the Either DSL Executor.

  Tests the runtime execution engine in isolation, focusing on:
  - Input lifting (various types → Either)
  - Result normalization (tuples/Either → Either)
  - Result wrapping (Either → :tuple/:raise/:either)

  For end-to-end pipeline execution, see dsl_test.exs.
  """

  use ExUnit.Case, async: true
  use Funx.Monad.Either

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Dsl.Executor

  # Tests input lifting for various input types
  describe "lift_input/1" do
    test "lifts plain value to Right" do
      assert Executor.lift_input(42) == Either.right(42)
    end

    test "passes through Right unchanged" do
      input = Either.right(42)
      assert Executor.lift_input(input) == input
    end

    test "passes through Left unchanged" do
      input = Either.left("error")
      assert Executor.lift_input(input) == input
    end

    test "converts {:ok, value} to Right" do
      assert Executor.lift_input({:ok, 42}) == Either.right(42)
    end

    test "converts {:error, reason} to Left" do
      assert Executor.lift_input({:error, "failed"}) == Either.left("failed")
    end

    test "lifts nil to Right" do
      assert Executor.lift_input(nil) == Either.right(nil)
    end

    test "lifts complex data structures" do
      data = %{name: "Alice", age: 30}
      assert Executor.lift_input(data) == Either.right(data)
    end
  end

  # Tests normalization of module run/3 results
  describe "normalize_run_result/1" do
    test "converts {:ok, value} to Right" do
      assert Executor.normalize_run_result({:ok, 42}) == Either.right(42)
    end

    test "converts {:error, reason} to Left" do
      assert Executor.normalize_run_result({:error, "failed"}) == Either.left("failed")
    end

    test "passes through Right unchanged" do
      either = Either.right(42)
      assert Executor.normalize_run_result(either) == either
    end

    test "passes through Left unchanged" do
      either = Either.left("error")
      assert Executor.normalize_run_result(either) == either
    end

    test "raises ArgumentError for invalid return value" do
      assert_raise ArgumentError,
                   ~r/Operation must return either an Either struct or a result tuple/,
                   fn ->
                     Executor.normalize_run_result(:invalid)
                   end
    end

    test "raises ArgumentError for plain value" do
      assert_raise ArgumentError,
                   ~r/Operation must return either an Either struct or a result tuple/,
                   fn ->
                     Executor.normalize_run_result(42)
                   end
    end

    test "raises ArgumentError for list" do
      assert_raise ArgumentError,
                   ~r/Operation must return either an Either struct or a result tuple/,
                   fn ->
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
    test "as: :either passes through Right" do
      either = Either.right(42)
      assert Executor.wrap_result(either, :either) == either
    end

    test "as: :either passes through Left" do
      either = Either.left("error")
      assert Executor.wrap_result(either, :either) == either
    end

    test "as: :either raises for non-Either value" do
      assert_raise ArgumentError, ~r/Expected Either struct/, fn ->
        Executor.wrap_result(42, :either)
      end
    end

    test "as: :tuple converts Right to {:ok, value}" do
      assert Executor.wrap_result(Either.right(42), :tuple) == {:ok, 42}
    end

    test "as: :tuple converts Left to {:error, reason}" do
      assert Executor.wrap_result(Either.left("failed"), :tuple) == {:error, "failed"}
    end

    test "as: :raise returns value on Right" do
      assert Executor.wrap_result(Either.right(42), :raise) == 42
    end

    test "as: :raise raises on Left" do
      assert_raise RuntimeError, "failed", fn ->
        Executor.wrap_result(Either.left("failed"), :raise)
      end
    end
  end
end
