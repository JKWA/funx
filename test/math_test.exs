defmodule Funx.MathTest do
  use ExUnit.Case, async: true
  alias Funx.Math
  alias Funx.Monad.Maybe

  doctest Funx.Math

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

  describe "min/1" do
    test "takes min from a list of numbers" do
      assert Math.min([2, 3, 4]) == 2
    end

    test "handles an empty list by returning min finite" do
      assert Math.min([]) == Float.max_finite()
    end

    test "handles a single element list" do
      assert Math.min([7]) == 7
    end
  end

  describe "min/2" do
    test "takes min from two numbers" do
      assert Math.min(1, 2) == 1
    end
  end

  describe "mean/1" do
    test "takes Just mean from a list of numbers" do
      assert Math.mean([2, 3, 4]) == Maybe.pure(3)
    end

    test "handles an empty list by returning Nothing" do
      assert Math.mean([]) == Maybe.nothing()
    end

    test "handles a single element list" do
      assert Math.mean([7]) == Maybe.pure(7)
    end
  end

  describe "range/1" do
    test "takes Just range from a list of numbers" do
      assert Math.range([2, 3, 4]) == Maybe.pure(2)
    end

    test "handles an empty list by returning Nothing" do
      assert Math.range([]) == Maybe.nothing()
    end

    test "handles a single element list" do
      assert Math.range([7]) == Maybe.pure(0)
    end
  end

  describe "square/1" do
    test "squares a single positive number" do
      assert Math.square(3) == 9
    end

    test "squares a single negative number" do
      assert Math.square(-4) == 16
    end

    test "squares zero" do
      assert Math.square(0) == 0
    end

    test "squares a list of numbers" do
      assert Math.square([1, 2, 3]) == [1, 4, 9]
    end

    test "squares a list with negative numbers" do
      assert Math.square([-2, 5]) == [4, 25]
    end

    test "squares an empty list" do
      assert Math.square([]) == []
    end
  end

  describe "sum_of_squares/1" do
    test "computes sum of squares for a list of numbers" do
      assert Math.sum_of_squares([1, 2, 3]) == 14
    end

    test "computes sum of squares for a list with negative numbers" do
      assert Math.sum_of_squares([-2, 5]) == 29
    end

    test "computes sum of squares for a single element list" do
      assert Math.sum_of_squares([4]) == 16
    end

    test "computes sum of squares for an empty list" do
      assert Math.sum_of_squares([]) == 0
    end
  end

  describe "deviation/1" do
    test "computes deviations from the mean for a list of numbers" do
      assert Math.deviation([1, 2, 3, 4]) == Maybe.pure([-1.5, -0.5, 0.5, 1.5])
    end

    test "returns all zeros when the list contains identical numbers" do
      assert Math.deviation([5, 5, 5]) == Maybe.pure([0.0, 0.0, 0.0])
    end

    test "computes deviations from the mean for negative numbers" do
      assert Math.deviation([-3, -2, -1, 0]) == Maybe.pure([-1.5, -0.5, 0.5, 1.5])
    end

    test "returns Nothing for an empty list" do
      assert Math.deviation([]) == Maybe.nothing()
    end

    test "computes deviations correctly for a single-element list" do
      assert Math.deviation([10]) == Maybe.pure([0.0])
    end
  end

  describe "variance/1" do
    test "computes variance for a list of numbers" do
      assert Math.variance([1, 2, 3, 4]) == Maybe.pure(1.25)
    end

    test "computes variance for a list with identical numbers" do
      assert Math.variance([5, 5, 5]) == Maybe.pure(0.0)
    end

    test "computes variance for a list with negative numbers" do
      assert Math.variance([-3, -2, -1, 0]) == Maybe.pure(1.25)
    end

    test "returns Nothing for an empty list" do
      assert Math.variance([]) == Maybe.nothing()
    end

    test "computes variance correctly for a single-element list" do
      assert Math.variance([10]) == Maybe.pure(0.0)
    end
  end

  describe "std_dev/1" do
    test "computes standard deviation for a list of numbers" do
      assert Math.std_dev([1, 2, 3, 4]) == Maybe.pure(1.118033988749895)
    end

    test "computes standard deviation for a list with identical numbers" do
      assert Math.std_dev([5, 5, 5]) == Maybe.pure(0.0)
    end

    test "computes standard deviation for a list with negative numbers" do
      assert Math.std_dev([-3, -2, -1, 0]) == Maybe.pure(1.118033988749895)
    end

    test "returns Nothing for an empty list" do
      assert Math.std_dev([]) == Maybe.nothing()
    end

    test "computes standard deviation correctly for a single-element list" do
      assert Math.std_dev([10]) == Maybe.pure(0.0)
    end
  end
end
