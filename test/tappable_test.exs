defmodule Funx.TappableTest do
  use ExUnit.Case, async: true

  alias Funx.Tappable

  describe "Tappable protocol for Any (fallback)" do
    test "executes Kernel.tap for arbitrary values" do
      test_pid = self()
      result = Tappable.tap(42, fn x -> send(test_pid, {:tapped, x}) end)

      assert result == 42
      assert_received {:tapped, 42}
    end

    test "works with strings" do
      test_pid = self()
      result = Tappable.tap("hello", fn x -> send(test_pid, {:tapped, x}) end)

      assert result == "hello"
      assert_received {:tapped, "hello"}
    end

    test "works with maps" do
      test_pid = self()
      map = %{key: "value"}
      result = Tappable.tap(map, fn x -> send(test_pid, {:tapped, x}) end)

      assert result == map
      assert_received {:tapped, ^map}
    end

    test "works with lists" do
      test_pid = self()
      list = [1, 2, 3]
      result = Tappable.tap(list, fn x -> send(test_pid, {:tapped, x}) end)

      assert result == list
      assert_received {:tapped, ^list}
    end

    test "discards return value of side effect function" do
      result = Tappable.tap(5, fn _ -> :discarded end)
      assert result == 5
    end

    test "works in pipelines" do
      test_pid = self()

      result =
        10
        |> Tappable.tap(fn x -> send(test_pid, {:step1, x}) end)
        |> Tappable.tap(fn x -> send(test_pid, {:step2, x}) end)

      assert result == 10
      assert_received {:step1, 10}
      assert_received {:step2, 10}
    end
  end

  describe "Tappable protocol behavior for non-monadic types" do
    test "tap always returns the original value unchanged" do
      values = [
        42,
        "string",
        %{key: :value},
        [1, 2, 3],
        {:tuple, :value}
      ]

      for value <- values do
        result = Tappable.tap(value, fn _ -> :side_effect_result end)
        assert result == value, "Expected tap to return original value for #{inspect(value)}"
      end
    end

    test "side effect function exceptions are propagated" do
      assert_raise RuntimeError, "side effect error", fn ->
        Tappable.tap(42, fn _ -> raise "side effect error" end)
      end
    end

    test "tap can be used for debugging without changing values" do
      test_pid = self()

      result =
        [1, 2, 3]
        |> Enum.map(&(&1 * 2))
        |> Tappable.tap(fn x -> send(test_pid, {:debug, x}) end)
        |> Enum.sum()

      assert result == 12
      assert_received {:debug, [2, 4, 6]}
    end
  end
end
