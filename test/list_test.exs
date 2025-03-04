defmodule Funx.ListTest do
  use ExUnit.Case, async: true
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
end
