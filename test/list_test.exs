defmodule Funx.ListTest do
  use ExUnit.Case, async: true
  import Funx.Filterable
  import Funx.Foldable
  import Funx.Monad

  alias Funx.List
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Ord, as: OrdUtils

  doctest Funx.List

  describe "uniq/2" do
    test "removes duplicates" do
      assert List.uniq([:apple, :banana, :apple, :banana]) == [:apple, :banana]
    end
  end

  describe "union/2" do
    test "combines lists without duplicates" do
      assert List.union([:apple], [:banana, :apple]) == [:apple, :banana]
    end
  end

  describe "intersection/2" do
    test "finds common elements" do
      assert List.intersection([:apple, :banana], [:banana, :orange]) == [:banana]
    end
  end

  describe "difference/2" do
    test "finds elements in first list not in second" do
      assert List.difference([:apple, :banana], [:banana]) == [:apple]
    end
  end

  describe "symmetric_difference/2" do
    test "finds elements in either list but not both" do
      assert List.symmetric_difference([:apple, :banana], [:banana, :orange]) == [
               :apple,
               :orange
             ]
    end
  end

  describe "group/2" do
    test "groups consecutive equal elements" do
      assert List.group([1, 1, 2, 2, 2, 3, 1, 1]) == [[1, 1], [2, 2, 2], [3], [1, 1]]
    end

    test "returns empty list for empty input" do
      assert List.group([]) == []
    end

    test "returns single group for single element" do
      assert List.group([1]) == [[1]]
    end

    test "returns single group when all elements are equal" do
      assert List.group([:a, :a, :a]) == [[:a, :a, :a]]
    end

    test "returns separate groups when no consecutive elements are equal" do
      assert List.group([1, 2, 3]) == [[1], [2], [3]]
    end

    test "uses custom Eq for comparison" do
      case_insensitive_eq = %{
        eq?: fn a, b when is_binary(a) and is_binary(b) ->
          String.downcase(a) == String.downcase(b)
        end,
        not_eq?: fn a, b when is_binary(a) and is_binary(b) ->
          String.downcase(a) != String.downcase(b)
        end
      }

      assert List.group(["a", "A", "b", "B", "b"], case_insensitive_eq) == [
               ["a", "A"],
               ["b", "B", "b"]
             ]
    end

    test "preserves original values in groups" do
      assert List.group(["Cat", "cat", "DOG"]) == [["Cat"], ["cat"], ["DOG"]]
    end
  end

  describe "group_sort/2" do
    test "sorts and groups elements" do
      assert List.group_sort([1, 2, 1, 2, 1]) == [[1, 1, 1], [2, 2]]
    end

    test "returns empty list for empty input" do
      assert List.group_sort([]) == []
    end

    test "returns single group for single element" do
      assert List.group_sort([1]) == [[1]]
    end

    test "groups all equal elements together after sorting" do
      assert List.group_sort([3, 1, 2, 1, 3]) == [[1, 1], [2], [3, 3]]
    end

    test "uses custom Ord for sorting and grouping" do
      ord = OrdUtils.contramap(&String.downcase/1)

      assert List.group_sort(["b", "A", "a", "B"], ord) == [["A", "a"], ["b", "B"]]
    end
  end

  describe "elem?/3" do
    test "returns true when element is present (default Eq)" do
      assert List.elem?([1, 2, 3], 1)
      assert List.elem?([:banana, :apple], :apple)
    end

    test "returns false when element is not present" do
      refute List.elem?([1, 2, 3], 4)
      refute List.elem?([:apple, :banana], :orange)
    end

    test "works with empty list" do
      refute List.elem?([], 1)
    end

    test "uses custom Eq for comparison" do
      case_insensitive_eq = %{
        eq?: fn a, b when is_binary(a) and is_binary(b) ->
          String.downcase(a) == String.downcase(b)
        end,
        not_eq?: fn a, b when is_binary(a) and is_binary(b) ->
          String.downcase(a) != String.downcase(b)
        end
      }

      assert List.elem?(["hello", "world"], "HELLO", case_insensitive_eq)
      refute List.elem?(["goodbye"], "HELLO", case_insensitive_eq)
    end

    test "works with complex values under Eq" do
      map = %{a: 1}
      assert List.elem?([map, %{a: 2}], map)
    end

    test "distinguishes values when default Eq does not consider them equal" do
      refute List.elem?(["hello"], "HELLO")
    end
  end

  describe "subset?/2" do
    test "checks if one list is contained in another" do
      assert List.subset?([:apple], [:apple, :banana])
      refute List.subset?([:apple, :grape], [:apple, :banana])
    end
  end

  describe "superset?/2" do
    test "checks if one list fully contains another" do
      assert List.superset?([:apple, :banana], [:apple])
      refute List.superset?([:apple], [:apple, :banana])
    end
  end

  describe "sort/2" do
    test "sorts elements according to ordering" do
      assert List.sort([:banana, :apple]) == [:apple, :banana]
    end
  end

  describe "strict_sort/2" do
    test "sorts and removes duplicates" do
      assert List.strict_sort([:banana, :apple, :apple]) == [:apple, :banana]
    end
  end

  describe "ap/2" do
    test "applies a list of functions to a list of values" do
      funcs = [fn x -> x * 2 end, fn x -> x + 1 end]
      values = [1, 2, 3]

      assert ap(funcs, values) == [2, 4, 6, 2, 3, 4]
    end
  end

  describe "bind/2" do
    test "chains a monadic operation by applying a function that returns a list" do
      list = [1, 2, 3]
      func = fn x -> [x, x * 2] end

      assert bind(list, func) == [1, 2, 2, 4, 3, 6]
    end
  end

  describe "map/2" do
    test "maps a function over a list" do
      list = [1, 2, 3]
      func = fn x -> x + 10 end

      assert map(list, func) == [11, 12, 13]
    end
  end

  describe "fold_l/3" do
    test "folds a list from the left" do
      list = [1, 2, 3, 4]
      func = fn acc, x -> acc + x end

      assert fold_l(list, 0, func) == 10
    end
  end

  describe "fold_r/3" do
    test "folds a list from the right" do
      list = [1, 2, 3, 4]
      func = fn x, acc -> acc - x end

      assert fold_r(list, 0, func) == -10
    end
  end

  describe "guard/2" do
    test "returns the list when condition is true" do
      assert guard([1, 2, 3], true) == [1, 2, 3]
    end

    test "returns an empty list when condition is false" do
      assert guard([1, 2, 3], false) == []
    end
  end

  describe "filter/2" do
    test "filters out values that do not match the predicate" do
      assert filter([1, 2, 3, 4], fn x -> rem(x, 2) == 0 end) == [2, 4]
    end

    test "returns an empty list when no values match" do
      assert filter([1, 3, 5], fn x -> rem(x, 2) == 0 end) == []
    end
  end

  describe "filter_map/2" do
    test "filters and transforms values" do
      result =
        filter_map([1, 2, 3, 4], fn x ->
          if rem(x, 2) == 0, do: x * 10, else: nil
        end)

      assert result == [20, 40]
    end

    test "returns an empty list if all results are nil" do
      result =
        filter_map([1, 3, 5], fn x ->
          if rem(x, 2) == 0, do: x * 10, else: nil
        end)

      assert result == []
    end

    test "preserves order" do
      result =
        filter_map([5, 3, 2, 4], fn x ->
          if rem(x, 2) == 0, do: x * 10, else: nil
        end)

      assert result == [20, 40]
    end
  end

  describe "concat/1" do
    test "concatenates a list of lists in order using ListConcat" do
      input = [[1], [2, 3], [4]]
      assert List.concat(input) == [1, 2, 3, 4]
    end

    test "returns an empty list when given an empty list" do
      assert List.concat([]) == []
    end
  end

  describe "head/1" do
    test "returns Just with head for non-empty list" do
      assert List.head([1, 2, 3]) == %Funx.Monad.Maybe.Just{value: 1}
    end

    test "returns Nothing for empty list" do
      assert List.head([]) == %Funx.Monad.Maybe.Nothing{}
    end

    test "returns Nothing for non-list values" do
      assert List.head("not a list") == %Funx.Monad.Maybe.Nothing{}
      assert List.head(42) == %Funx.Monad.Maybe.Nothing{}
      assert List.head(nil) == %Funx.Monad.Maybe.Nothing{}
    end

    test "works with single-element list" do
      assert List.head([:only]) == %Just{value: :only}
    end
  end

  describe "head!/1" do
    test "returns head element for non-empty list" do
      assert List.head!([1, 2, 3]) == 1
    end

    test "raises on empty list" do
      assert_raise ArgumentError, "cannot get head of empty list", fn ->
        List.head!([])
      end
    end

    test "raises on non-list values" do
      assert_raise ArgumentError, "cannot get head of empty list", fn ->
        List.head!("not a list")
      end
    end

    test "works with single-element list" do
      assert List.head!([:only]) == :only
    end
  end

  describe "tail/1" do
    test "returns tail for non-empty list" do
      assert List.tail([1, 2, 3]) == [2, 3]
    end

    test "returns empty list for single-element list" do
      assert List.tail([42]) == []
    end

    test "returns empty list for empty list" do
      assert List.tail([]) == []
    end
  end

  describe "max/2" do
    test "returns Just with maximum element for non-empty list" do
      assert List.max([3, 1, 4, 1, 5]) == %Just{value: 5}
    end

    test "returns Nothing for empty list" do
      assert List.max([]) == %Nothing{}
    end

    test "works with single element" do
      assert List.max([42]) == %Just{value: 42}
    end

    test "works with custom Ord" do
      ord = OrdUtils.contramap(&String.length/1)
      assert List.max(["cat", "elephant", "ox"], ord) == %Just{value: "elephant"}
    end

    test "works with negative numbers" do
      assert List.max([-5, -1, -10, -3]) == %Just{value: -1}
    end
  end

  describe "max!/2" do
    test "returns maximum element for non-empty list" do
      assert List.max!([3, 1, 4, 1, 5]) == 5
    end

    test "raises on empty list" do
      assert_raise Enum.EmptyError, fn ->
        List.max!([])
      end
    end

    test "works with single element" do
      assert List.max!([42]) == 42
    end

    test "works with custom Ord" do
      ord = OrdUtils.contramap(&String.length/1)
      assert List.max!(["cat", "elephant", "ox"], ord) == "elephant"
    end
  end

  describe "min/2" do
    test "returns Just with minimum element for non-empty list" do
      assert List.min([3, 1, 4, 1, 5]) == %Funx.Monad.Maybe.Just{value: 1}
    end

    test "returns Nothing for empty list" do
      assert List.min([]) == %Funx.Monad.Maybe.Nothing{}
    end

    test "works with single element" do
      assert List.min([42]) == %Just{value: 42}
    end

    test "works with custom Ord" do
      ord = OrdUtils.contramap(&String.length/1)
      assert List.min(["cat", "elephant", "ox"], ord) == %Just{value: "ox"}
    end

    test "works with negative numbers" do
      assert List.min([-5, -1, -10, -3]) == %Just{value: -10}
    end
  end

  describe "min!/2" do
    test "returns minimum element for non-empty list" do
      assert List.min!([3, 1, 4, 1, 5]) == 1
    end

    test "raises on empty list" do
      assert_raise Enum.EmptyError, fn ->
        List.min!([])
      end
    end

    test "works with single element" do
      assert List.min!([42]) == 42
    end

    test "works with custom Ord" do
      ord = OrdUtils.contramap(&String.length/1)
      assert List.min!(["cat", "elephant", "ox"], ord) == "ox"
    end
  end
end
