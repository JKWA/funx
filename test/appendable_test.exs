defmodule Funx.AppendableTest do
  use ExUnit.Case, async: true

  doctest Funx.Appendable

  import Funx.Appendable

  describe "Appendable for Any" do
    test "coerce/1 wraps a non-list value in a list" do
      assert coerce("error") == ["error"]
      assert coerce(123) == [123]
      assert coerce(nil) == [nil]
    end

    test "append/2 merges wrapped and accumulator values in order" do
      assert append("old", "new") == ["old", "new"]
      assert append(["a"], "b") == ["a", "b"]
      assert append("a", ["b"]) == ["a", "b"]
      assert append(["a"], ["b"]) == ["a", "b"]
    end
  end
end
