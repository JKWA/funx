defmodule Monex.ListConcatTest do
  use ExUnit.Case
  import Monex.Monoid
  alias Monex.Monoid.ListConcat

  describe "empty/1" do
    test "returns a ListConcat with an empty list" do
      assert empty(%ListConcat{}) == %ListConcat{value: []}
    end
  end

  describe "wrap/2" do
    test "wraps a list into a ListConcat struct" do
      assert wrap(%ListConcat{}, [1, 2, 3]) == %ListConcat{value: [1, 2, 3]}
      assert wrap(%ListConcat{}, []) == %ListConcat{value: []}
    end
  end

  describe "unwrap/1" do
    test "unwraps the value from a ListConcat struct" do
      assert unwrap(%ListConcat{value: [1, 2, 3]}) == [1, 2, 3]
      assert unwrap(%ListConcat{value: []}) == []
    end
  end

  describe "append/2" do
    test "concatenates two ListConcat structs" do
      a = %ListConcat{value: [1, 2]}
      b = %ListConcat{value: [3, 4]}
      assert append(a, b) == %ListConcat{value: [1, 2, 3, 4]}
    end

    test "concatenating with empty identity returns the original" do
      a = %ListConcat{value: [1, 2, 3]}
      empty = empty(%ListConcat{})
      assert append(a, empty) == a
      assert append(empty, a) == a
    end

    test "concatenating two empty ListConcat structs returns empty" do
      empty = empty(%ListConcat{})
      assert append(empty, empty) == empty
    end
  end
end
