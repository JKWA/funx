defmodule Funx.Predicate.ListTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Eq, List}

  describe "List predicate standalone" do
    test "returns true for lists" do
      predicate = List.pred()

      assert predicate.([])
      assert predicate.([1, 2, 3])
      assert predicate.([:a, :b])
      assert predicate.(["hello", "world"])
    end

    test "returns false for non-lists" do
      predicate = List.pred()

      refute predicate.(5)
      refute predicate.("list")
      refute predicate.(:list)
      refute predicate.(nil)
      refute predicate.(%{key: "value"})
      refute predicate.({1, 2, 3})
    end
  end

  describe "List predicate in DSL" do
    test "check with List" do
      is_list_tags =
        pred do
          check :tags, List
        end

      assert is_list_tags.(%{tags: []})
      assert is_list_tags.(%{tags: [1, 2, 3]})
      assert is_list_tags.(%{tags: ["a", "b"]})
      refute is_list_tags.(%{tags: "not a list"})
      refute is_list_tags.(%{})
    end

    test "negate check with List" do
      not_list =
        pred do
          negate check :value, List
        end

      assert not_list.(%{value: "hello"})
      assert not_list.(%{value: 42})
      refute not_list.(%{value: [1, 2, 3]})
    end

    test "combined with negate for type checking" do
      must_be_list =
        pred do
          check :items, List
          negate check :items, {Eq, value: []}
        end

      assert must_be_list.(%{items: [1]})
      assert must_be_list.(%{items: [1, 2, 3]})
      refute must_be_list.(%{items: []})
      refute must_be_list.(%{items: "not a list"})
    end
  end
end
