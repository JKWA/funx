defmodule Funx.StringConcatTest do
  use ExUnit.Case
  import Funx.Monoid
  alias Funx.Monoid.StringConcat

  describe "empty/1" do
    test "returns a StringConcat with an empty string" do
      assert empty(%StringConcat{}) == %StringConcat{value: ""}
    end
  end

  describe "wrap/2" do
    test "wraps a string into a StringConcat struct" do
      assert wrap(%StringConcat{}, "abc") == %StringConcat{value: "abc"}
      assert wrap(%StringConcat{}, "") == %StringConcat{value: ""}
    end
  end

  describe "unwrap/1" do
    test "unwraps the value from a StringConcat struct" do
      assert unwrap(%StringConcat{value: "abc"}) == "abc"
      assert unwrap(%StringConcat{value: ""}) == ""
    end
  end

  describe "append/2" do
    test "concatenates two StringConcat structs" do
      a = %StringConcat{value: "foo"}
      b = %StringConcat{value: "bar"}
      assert append(a, b) == %StringConcat{value: "foobar"}
    end

    test "concatenating with empty identity returns the original" do
      a = %StringConcat{value: "hello"}
      empty = empty(%StringConcat{})
      assert append(a, empty) == a
      assert append(empty, a) == a
    end

    test "concatenating two empty StringConcat structs returns empty" do
      empty = empty(%StringConcat{})
      assert append(empty, empty) == empty
    end
  end
end
