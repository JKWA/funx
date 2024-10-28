defmodule Monex.TelemetryUtilsTest do
  use ExUnit.Case, async: true
  alias Monex.TelemetryUtils

  describe "summarize/1" do
    test "returns nil as-is" do
      assert TelemetryUtils.summarize(nil) == nil
    end

    test "summarizes atoms" do
      assert TelemetryUtils.summarize(:example) == {:atom, :example}
    end

    test "summarizes integers" do
      assert TelemetryUtils.summarize(42) == {:integer, 42}
    end

    test "summarizes floats" do
      assert TelemetryUtils.summarize(3.14) == {:float, 3.14}
    end

    test "summarizes binaries with byte size" do
      assert TelemetryUtils.summarize("hello") == {:binary, 5}
    end

    test "summarizes empty lists" do
      assert TelemetryUtils.summarize([]) == {:list, :empty}
    end

    test "summarizes non-empty lists with up to 3 elements" do
      assert TelemetryUtils.summarize([1, 2, 3, 4]) ==
               {:list, [{:integer, 1}, {:integer, 2}, {:integer, 3}]}

      assert TelemetryUtils.summarize([1, "two", :three]) ==
               {:list, [{:integer, 1}, {:binary, 3}, {:atom, :three}]}
    end

    test "summarizes empty maps" do
      assert TelemetryUtils.summarize(%{}) == {:map, :empty}
    end

    test "summarizes non-empty maps with up to 3 key-value pairs" do
      result = TelemetryUtils.summarize(%{a: 1, b: "two", c: :three, d: 4})
      expected = {:map, [a: {:integer, 1}, b: {:binary, 3}, c: {:atom, :three}]}
      assert result == expected
    end

    test "summarizes empty tuples" do
      assert TelemetryUtils.summarize({}) == {:tuple, :empty}
    end

    test "summarizes tuples with up to 3 elements" do
      result = TelemetryUtils.summarize({1, "two", :three, 4.0})
      expected = {:tuple, [{:integer, 1}, {:binary, 3}, {:atom, :three}]}
      assert result == expected
    end

    test "summarizes functions as :function" do
      assert TelemetryUtils.summarize(&(&1 + 1)) == :function
    end

    test "summarizes PIDs as :pid" do
      assert TelemetryUtils.summarize(self()) == :pid
    end

    test "summarizes ports as :port" do
      {:ok, port} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      assert TelemetryUtils.summarize(port) == :port
      :gen_tcp.close(port)
    end

    test "summarizes references as :reference" do
      assert TelemetryUtils.summarize(make_ref()) == :reference
    end

    test "summarizes bitstrings with bit size" do
      bitstring = <<1::3>>
      assert TelemetryUtils.summarize(bitstring) == {:bitstring, 3}
    end
  end
end
