defmodule Funx.ListTest do
  use ExUnit.Case, async: true
  import Funx.Foldable
  import Funx.Monad

  alias Funx.List
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

      assert fold_l(list, func, 0) == 10
    end
  end

  describe "fold_r/3" do
    test "folds a list from the right" do
      list = [1, 2, 3, 4]
      func = fn x, acc -> acc - x end

      assert fold_r(list, func, 0) == -10
    end
  end
end
