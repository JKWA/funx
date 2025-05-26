defmodule Funx.SemigroupTest do
  use ExUnit.Case, async: true

  doctest Funx.Semigroup

  alias Funx.Semigroup

  describe "Funx.Semigroup for List" do
    test "wrap/1 returns the list unchanged" do
      assert Semigroup.wrap(["a", "b"]) == ["a", "b"]
    end

    test "unwrap/1 returns the list unchanged" do
      assert Semigroup.unwrap(["a", "b"]) == ["a", "b"]
    end

    test "append/2 concatenates lists in order" do
      acc = ["x"]
      new = ["y", "z"]
      assert Semigroup.append(acc, new) == ["x", "y", "z"]
    end
  end

  describe "Funx.Semigroup for Any" do
    test "wrap/1 wraps a non-list value in a list" do
      assert Semigroup.wrap("error") == ["error"]
      assert Semigroup.wrap(123) == [123]
      assert Semigroup.wrap(nil) == [nil]
    end

    test "append/2 merges wrapped and accumulator values in order" do
      assert Semigroup.append("old", "new") == ["old", "new"]
      assert Semigroup.append(["a"], "b") == ["a", "b"]
      assert Semigroup.append("a", ["b"]) == ["a", "b"]
      assert Semigroup.append(["a"], ["b"]) == ["a", "b"]
    end
  end
end
