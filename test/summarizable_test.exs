defmodule Funx.SummarizableTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Funx.Summarizable, only: [summarize: 1]
  alias Funx.Test.Person

  describe "summarize/1" do
    test "returns nil as-is" do
      assert summarize(nil) == nil
    end

    test "summarizes atoms" do
      assert summarize(:example) == {:atom, :example}
    end

    test "summarizes integers" do
      assert summarize(42) == {:integer, 42}
    end

    test "summarizes floats" do
      assert summarize(3.14) == {:float, 3.14}
    end

    test "summarizes strings" do
      assert summarize("hello") == {:string, "hello"}
    end

    test "summarizes empty lists" do
      assert summarize([]) == {:list, :empty}
    end

    test "summarizes non-empty lists with up to 3 elements" do
      assert summarize([1, 2, 3, 4]) ==
               {:list, [{:integer, 1}, {:integer, 2}, {:integer, 3}]}

      assert summarize([1, "two", :three]) ==
               {:list, [{:integer, 1}, {:string, "two"}, {:atom, :three}]}
    end

    test "summarizes empty maps" do
      assert summarize(%{}) == {:map, :empty}
    end

    test "summarizes non-empty maps with up to 3 key-value pairs" do
      result = summarize(%{a: 1, b: "two", c: :three, d: 4})
      expected = {:map, [a: {:integer, 1}, b: {:string, "two"}, c: {:atom, :three}]}
      assert result == expected
    end

    test "summarizes empty tuples" do
      assert summarize({}) == {:tuple, :empty}
    end

    test "summarizes tuples with up to 3 elements" do
      result = summarize({1, "two", :three, 4.0})
      expected = {:tuple, [{:integer, 1}, {:string, "two"}, {:atom, :three}]}
      assert result == expected
    end

    test "summarizes functions as :function" do
      assert summarize(&(&1 + 1)) == :function
    end

    test "summarizes PIDs as :pid" do
      assert summarize(self()) == :pid
    end

    test "summarizes ports as :port" do
      {:ok, port} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      assert summarize(port) == :port
      :gen_tcp.close(port)
    end

    test "summarizes references as :reference" do
      assert summarize(make_ref()) == :reference
    end

    test "summarizes non-binary bitstring" do
      bitstring = <<1::3>>
      assert summarize(bitstring) == {:bitstring, "<<3 bits>>"}
    end

    test "summarizes unknown structs" do
      p1 = %Person{name: "Alice", age: 30}

      assert summarize(p1) ==
               {:map,
                [
                  __module__: {:atom, Funx.Test.Person},
                  age: {:integer, 30},
                  name: {:string, "Alice"}
                ]}
    end
  end
end
