defmodule Funx.Predicate.NonEmptyTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.NonEmpty

  describe "NonEmpty predicate standalone" do
    test "returns true for non-empty lists" do
      predicate = NonEmpty.pred()

      assert predicate.([1, 2, 3])
      assert predicate.([:a, :b])
      assert predicate.(["hello", "world"])
      assert predicate.([1])
    end

    test "returns false for empty lists" do
      predicate = NonEmpty.pred()

      refute predicate.([])
    end

    test "returns false for non-lists" do
      predicate = NonEmpty.pred()

      refute predicate.(5)
      refute predicate.("list")
      refute predicate.(:list)
      refute predicate.(nil)
      refute predicate.(%{key: "value"})
      refute predicate.({1, 2, 3})
    end
  end

  describe "NonEmpty predicate in DSL" do
    test "check with NonEmpty" do
      is_non_empty_list_tags =
        pred do
          check :tags, NonEmpty
        end

      assert is_non_empty_list_tags.(%{tags: [1, 2, 3]})
      assert is_non_empty_list_tags.(%{tags: ["a", "b"]})
      assert is_non_empty_list_tags.(%{tags: [1]})
      refute is_non_empty_list_tags.(%{tags: []})
      refute is_non_empty_list_tags.(%{tags: "not a list"})
      refute is_non_empty_list_tags.(%{})
    end

    test "negate check with NonEmpty" do
      is_empty_or_not_list =
        pred do
          negate check :value, NonEmpty
        end

      assert is_empty_or_not_list.(%{value: []})
      assert is_empty_or_not_list.(%{value: "hello"})
      assert is_empty_or_not_list.(%{value: 42})
      refute is_empty_or_not_list.(%{value: [1, 2, 3]})
    end

    test "combined with other predicates" do
      alias Funx.Predicate.Contains

      has_specific_item =
        pred do
          check :items, NonEmpty
          check :items, {Contains, value: :required}
        end

      assert has_specific_item.(%{items: [:required, :optional]})
      assert has_specific_item.(%{items: [:required]})
      refute has_specific_item.(%{items: []})
      refute has_specific_item.(%{items: [:optional, :other]})
    end
  end
end
