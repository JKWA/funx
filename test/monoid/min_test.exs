defmodule Monex.Monoid.MinTest do
  use ExUnit.Case, async: true
  alias Monex.Monoid

  def min_value(numbers) do
    Monoid.Utils.concat(
      %Monoid.Min{value: nil, ord: Monex.Ord},
      numbers
    )
  end

  describe "Min Monoid" do
    test "selects the smallest number" do
      assert min_value([1, 3, 2, 5, 4]) == 1
      assert min_value([10, -5, 0, 7]) == -5
      assert min_value([]) == nil
    end
  end
end
