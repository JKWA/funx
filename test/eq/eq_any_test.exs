defmodule Funx.EqAnyTest do
  @moduledoc false

  use ExUnit.Case
  alias Funx.Eq

  describe "Funx.Eq.eq?/2 with default implementation" do
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

  describe "Funx.Eq.not_eq?/2 with default implementation" do
    test "returns false for integers that are equal" do
      assert Eq.not_eq?(1, 1) == false
    end

    test "returns true for integers that are not equal" do
      assert Eq.not_eq?(1, 2) == true
    end

    test "returns false for strings that are equal" do
      assert Eq.not_eq?("hello", "hello") == false
    end

    test "returns true for strings that are not equal" do
      assert Eq.not_eq?("hello", "world") == true
    end

    test "returns false for lists that are equal" do
      assert Eq.not_eq?([1, 2, 3], [1, 2, 3]) == false
    end

    test "returns true for lists that are not equal" do
      assert Eq.not_eq?([1, 2], [1, 2, 3]) == true
    end

    test "returns false for maps that are equal" do
      assert Eq.not_eq?(%{a: 1}, %{a: 1}) == false
    end

    test "returns true for maps that are not equal" do
      assert Eq.not_eq?(%{a: 1}, %{a: 2}) == true
    end

    test "returns false for tuples that are equal" do
      assert Eq.not_eq?({:ok, 1}, {:ok, 1}) == false
    end

    test "returns true for tuples that are not equal" do
      assert Eq.not_eq?({:ok, 1}, {:error, 1}) == true
    end
  end
end
