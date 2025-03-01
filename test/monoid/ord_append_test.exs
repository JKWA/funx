defmodule Monex.Ord.AppendTest do
  use ExUnit.Case, async: true
  alias Monex.Monoid

  test "append delegates to ord2 for ge? when ord1 considers a and b equal" do
    ord1 = %Monoid.Ord{
      lt?: fn _, _ -> false end,
      le?: fn _, _ -> true end,
      gt?: fn _, _ -> false end,
      ge?: fn _, _ -> true end
    }

    ord2 = %Monoid.Ord{
      lt?: fn a, b -> a < b end,
      le?: fn a, b -> a <= b end,
      gt?: fn a, b -> a > b end,
      ge?: fn a, b -> a >= b end
    }

    combined_ord = Monoid.append(ord1, ord2)

    assert combined_ord.ge?.(3, 3) == true
    assert combined_ord.ge?.(4, 3) == true
    assert combined_ord.ge?.(2, 3) == false
  end
end
