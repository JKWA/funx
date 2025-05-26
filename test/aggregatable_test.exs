defmodule Funx.AggregatableTest do
  use ExUnit.Case, async: true

  doctest Funx.Aggregatable

  alias Funx.Aggregatable

  describe "Funx.Aggregatable for List" do
    test "wrap/1 returns the list unchanged" do
      assert Aggregatable.wrap(["a", "b"]) == ["a", "b"]
    end

    test "combine/2 concatenates lists in order" do
      acc = ["x"]
      new = ["y", "z"]
      assert Aggregatable.combine(acc, new) == ["x", "y", "z"]
    end
  end

  describe "Funx.Aggregatable for Any" do
    test "wrap/1 wraps a non-list value in a list" do
      assert Aggregatable.wrap("error") == ["error"]
      assert Aggregatable.wrap(123) == [123]
      assert Aggregatable.wrap(nil) == [nil]
    end

    test "combine/2 merges wrapped and accumulator values in order" do
      assert Aggregatable.combine("old", "new") == ["old", "new"]
      assert Aggregatable.combine(["a"], "b") == ["a", "b"]
      assert Aggregatable.combine("a", ["b"]) == ["a", "b"]
      assert Aggregatable.combine(["a"], ["b"]) == ["a", "b"]
    end
  end
end
