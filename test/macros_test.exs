defmodule Monex.MacrosTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Monex.Eq
  alias Monex.Ord
  alias Monex.Test.Person

  describe "eq_for/2 macro" do
    test "eq?/2 compares structs based on the specified field" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Charlie", age: 25}

      assert Eq.eq?(p1, p2)
      refute Eq.eq?(p1, p3)
    end

    test "not_eq?/2 negates eq?/2" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Charlie", age: 25}

      refute Eq.not_eq?(p1, p2)
      assert Eq.not_eq?(p1, p3)
    end
  end

  describe "ord_for/2 macro" do
    test "lt?/2 determines if the first struct's field is less than the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 25}

      assert Ord.lt?(p2, p1)
      refute Ord.lt?(p1, p2)
    end

    test "le?/2 determines if the first struct's field is less than or equal to the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Charlie", age: 25}

      assert Ord.le?(p3, p1)
      assert Ord.le?(p1, p2)
      refute Ord.le?(p1, p3)
    end

    test "gt?/2 determines if the first struct's field is greater than the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 35}

      assert Ord.gt?(p2, p1)
      refute Ord.gt?(p1, p2)
    end

    test "ge?/2 determines if the first struct's field is greater than or equal to the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Charlie", age: 35}

      assert Ord.ge?(p3, p1)
      assert Ord.ge?(p1, p2)
      refute Ord.ge?(p1, p3)
    end
  end
end
