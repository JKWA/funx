defmodule Funx.UtilsTest do
  use ExUnit.Case, async: true
  import Funx.Utils

  describe "curry/1" do
    test "curries a function with arity 2" do
      add = fn a, b -> a + b end
      curried_add = curry(add)

      assert is_function(curried_add)
      add_five = curried_add.(5)
      assert is_function(add_five)
      assert add_five.(3) == 8
    end

    test "curries a function with arity 3" do
      multiply = fn a, b, c -> a * b * c end
      curried_multiply = curry(multiply)

      assert is_function(curried_multiply)
      step1 = curried_multiply.(2)
      assert is_function(step1)
      step2 = step1.(3)
      assert is_function(step2)
      assert step2.(4) == 24
    end

    test "currying works with a single argument function" do
      identity = fn x -> x end
      curried_identity = curry(identity)

      assert is_function(curried_identity)
      assert curried_identity.(42) == 42
    end
  end

  describe "curry_l/1" do
    test "curry_l is identical to curry" do
      add = fn a, b -> a + b end
      curried_add_l = curry_l(add)
      curried_add = curry(add)

      assert curried_add_l.(5).(3) == curried_add.(5).(3)
    end

    test "curry_l applies arguments left-to-right" do
      subtract = fn a, b -> a - b end
      curried_subtract_l = curry_l(subtract)

      assert is_function(curried_subtract_l)
      subtract_five = curried_subtract_l.(5)
      assert is_function(subtract_five)
      assert subtract_five.(3) == 2
    end
  end

  describe "curry_r/1" do
    test "right curries a function with arity 2" do
      subtract = fn a, b -> a - b end
      curried_subtract = curry_r(subtract)

      assert is_function(curried_subtract)
      minus_three = curried_subtract.(3)
      assert is_function(minus_three)
      assert minus_three.(10) == 7
    end

    test "right curries a function with arity 3" do
      divide = fn a, b, c -> a / b / c end
      curried_divide = curry_r(divide)

      assert is_function(curried_divide)
      step1 = curried_divide.(2)
      assert is_function(step1)
      step2 = step1.(4)
      assert is_function(step2)
      assert step2.(16) == 2.0
    end

    test "right currying works with a single argument function" do
      identity = fn x -> x end
      curried_identity = curry_r(identity)

      assert is_function(curried_identity)
      assert curried_identity.(42) == 42
    end
  end

  describe "flip/1" do
    test "flips a function with arity 2" do
      subtract = fn a, b -> a - b end
      flipped_subtract = flip(subtract)

      assert is_function(flipped_subtract)
      assert flipped_subtract.(10, 3) == -7
      assert flipped_subtract.(5, 20) == 15
    end

    test "flipping works with string concatenation" do
      concat = fn first, second -> first <> second end
      flipped_concat = flip(concat)

      assert is_function(flipped_concat)
      assert flipped_concat.("hello", "world") == "worldhello"
    end

    test "flipping works with tuple construction" do
      tuple_fun = fn a, b -> {a, b} end
      flipped_tuple_fun = flip(tuple_fun)

      assert is_function(flipped_tuple_fun)
      assert flipped_tuple_fun.(:first, :second) == {:second, :first}
    end
  end
end
