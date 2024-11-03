defmodule Monex.EqAnyTest do
  use ExUnit.Case
  alias Monex.Eq

  describe "Monex.Eq.eq?/2 with default implementation" do
    test "returns true for integers that are equal" do
      assert Eq.eq?(1, 1) == true
    end

    test "returns false for integers that are not equal" do
      assert Eq.eq?(1, 2) == false
    end

    test "returns true for strings that are equal" do
      assert Eq.eq?("hello", "hello") == true
    end

    test "returns false for strings that are not equal" do
      assert Eq.eq?("hello", "world") == false
    end

    test "returns true for lists that are equal" do
      assert Eq.eq?([1, 2, 3], [1, 2, 3]) == true
    end

    test "returns false for lists that are not equal" do
      assert Eq.eq?([1, 2], [1, 2, 3]) == false
    end

    test "returns true for maps that are equal" do
      assert Eq.eq?(%{a: 1}, %{a: 1}) == true
    end

    test "returns false for maps that are not equal" do
      assert Eq.eq?(%{a: 1}, %{a: 2}) == false
    end

    test "returns true for tuples that are equal" do
      assert Eq.eq?({:ok, 1}, {:ok, 1}) == true
    end

    test "returns false for tuples that are not equal" do
      assert Eq.eq?({:ok, 1}, {:error, 1}) == false
    end
  end
end
