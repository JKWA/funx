defmodule Funx.EnumTest do
  use ExUnit.Case, async: true
  alias Funx.Enum
  doctest Funx.Enum

  describe "uniq/2" do
    test "removes duplicates" do
      assert Enum.uniq([:apple, :banana, :apple, :banana]) == [:apple, :banana]
    end
  end

  describe "union/2" do
    test "combines lists without duplicates" do
      assert Enum.union([:apple], [:banana, :apple]) == [:apple, :banana]
    end
  end

  describe "intersection/2" do
    test "finds common elements" do
      assert Enum.intersection([:apple, :banana], [:banana, :orange]) == [:banana]
    end
  end

  describe "difference/2" do
    test "finds elements in first list not in second" do
      assert Enum.difference([:apple, :banana], [:banana]) == [:apple]
    end
  end

  describe "symmetric_difference/2" do
    test "finds elements in either list but not both" do
      assert Enum.symmetric_difference([:apple, :banana], [:banana, :orange]) == [
               :apple,
               :orange
             ]
    end
  end

  describe "subset?/2" do
    test "checks if one list is contained in another" do
      assert Enum.subset?([:apple], [:apple, :banana])
      refute Enum.subset?([:apple, :grape], [:apple, :banana])
    end
  end

  describe "superset?/2" do
    test "checks if one list fully contains another" do
      assert Enum.superset?([:apple, :banana], [:apple])
      refute Enum.superset?([:apple], [:apple, :banana])
    end
  end

  describe "sort/2" do
    test "sorts elements according to ordering" do
      assert Enum.sort([:banana, :apple]) == [:apple, :banana]
    end
  end

  describe "strict_sort/2" do
    test "sorts and removes duplicates" do
      assert Enum.strict_sort([:banana, :apple, :apple]) == [:apple, :banana]
    end
  end
end
