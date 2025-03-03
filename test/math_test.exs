defmodule Funx.MathTest do
  use ExUnit.Case, async: true
  alias Funx.Math

  describe "sum/2" do
    test "combines two numbers correctly" do
      assert Math.sum(2, 3) == 5
    end

    test "combines a positive and a negative number" do
      assert Math.sum(10, -5) == 5
    end

    test "combines zero with a number" do
      assert Math.sum(0, 7) == 7
    end
  end

  describe "sum/1" do
    test "sums a list of numbers" do
      assert Math.sum([1, 2, 3, 4]) == 10
    end

    test "handles an empty list by returning 0" do
      assert Math.sum([]) == 0
    end

    test "handles a single element list" do
      assert Math.sum([5]) == 5
    end
  end

  describe "product/2" do
    test "multiplies two numbers correctly" do
      assert Math.product(3, 4) == 12
    end

    test "multiplies a number by one" do
      assert Math.product(7, 1) == 7
    end

    test "multiplies a number by zero" do
      assert Math.product(5, 0) == 0
    end
  end

  describe "product/1" do
    test "multiplies a list of numbers" do
      assert Math.product([2, 3, 4]) == 24
    end

    test "handles an empty list by returning 1" do
      assert Math.product([]) == 1
    end

    test "handles a single element list" do
      assert Math.product([7]) == 7
    end
  end

  describe "max/1" do
    test "takes max from a list of numbers" do
      assert Math.max([2, 3, 4]) == 4
    end

    test "handles an empty list by returning min finite" do
      assert Math.max([]) == Float.min_finite()
    end

    test "handles a single element list" do
      assert Math.max([7]) == 7
    end
  end

  describe "max/2" do
    test "takes max from two numbers" do
      assert Math.max(1, 2) == 2
    end
  end
end
