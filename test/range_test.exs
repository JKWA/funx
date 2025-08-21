defmodule Funx.Foldable.RangeTest do
  use ExUnit.Case
  import Funx.Foldable

  describe "Funx.Foldable implementation for Range" do
    test "fold_l reduces left-to-right" do
      result = fold_l(1..3, [], fn x, acc -> [x | acc] end)
      assert result == [3, 2, 1]
    end

    test "fold_r reduces right-to-left" do
      result = fold_r(1..3, [], fn x, acc -> [x | acc] end)
      assert result == [1, 2, 3]
    end

    test "fold_l with sum function" do
      result = fold_l(1..4, 0, &+/2)
      assert result == 10
    end

    test "fold_r with subtraction" do
      result = fold_r(1..3, 0, &-/2)
      assert result == 2
    end
  end
end
