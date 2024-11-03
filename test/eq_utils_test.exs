defmodule Monex.Eq.UtilsTest do
  use ExUnit.Case, async: true

  alias Monex.Eq.Utils
  alias Monex.Maybe

  describe "contramap/2" do
    test "applies the function before comparing values using eq?" do
      eq_by_length = Utils.contramap(&String.length/1)

      assert eq_by_length.eq?.("short_a", "short_b") == true
      assert eq_by_length.eq?.("short", "longer") == false
    end
  end

  describe "eq_by?/3" do
    test "checks equality of values by applying a projection function" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      assert Utils.eq_by?(& &1.name, person1, person2) == true
      assert Utils.eq_by?(& &1.name, person1, person3) == false

      assert Utils.eq_by?(& &1.age, person1, person2) == false
      assert Utils.eq_by?(& &1.age, person1, person3) == true
    end
  end

  describe "not_eq?/2" do
    test "returns true if values are not equal" do
      assert Utils.not_eq?(1, 2) == true
      assert Utils.not_eq?(3, 3) == false
    end

    test "works with maps" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      assert Utils.not_eq?(person1[:name], person3[:name]) == true
      assert Utils.not_eq?(person1[:name], person2[:name]) == false
    end
  end

  def custom_eq do
    %{
      eq?: fn a, b -> a.name == b.name and a.age == b.age end
    }
  end

  describe "contramap/2 with custom Eq" do
    test "applies the function before comparing full maps with custom eq?" do
      eq_with_custom = Utils.contramap(& &1, custom_eq())

      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 30}
      person3 = %{name: "Alice", age: 25}

      assert eq_with_custom[:eq?].(person1, person2) == true
      assert eq_with_custom[:eq?].(person1, person3) == false
    end
  end

  describe "not_eq?/3 with custom Eq" do
    test "returns true if full maps are not equal according to custom eq?" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 30}
      person3 = %{name: "Alice", age: 25}
      person4 = %{name: "Bob", age: 30}

      assert Utils.not_eq?(person1, person3, custom_eq()) == true
      assert Utils.not_eq?(person1, person2, custom_eq()) == false
      assert Utils.not_eq?(person1, person4, custom_eq()) == true
    end
  end

  def within_5_eq do
    %{
      eq?: fn a, b -> abs(a - b) <= 5 end
    }
  end

  describe "to_predicate/2 with custom within_5_eq" do
    test "filters elements within 5 units of target number" do
      list = [1, 2, 3, 8, 10, 15, 20]
      target_number = 10

      result = Enum.filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == [8, 10, 15]
    end

    test "returns an empty list if no elements are within 5 units of target number" do
      list = [1, 2, 3, 20, 25]
      target_number = 10

      result = Enum.filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == []
    end

    test "includes all elements if all are within 5 units of target number" do
      list = [7, 8, 10, 12, 14]
      target_number = 10

      result = Enum.filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == [7, 8, 10, 12, 14]
    end
  end

  def within_5_eq_maybe do
    %{
      eq?: fn
        %Maybe.Just{value: a}, %Maybe.Just{value: b} -> abs(a - b) <= 5
        _, _ -> false
      end
    }
  end

  describe "to_predicate/2 with custom within_5_eq for Maybe.just and Maybe.nothing" do
    test "filters elements within 5 units of target Just number" do
      list = [
        Maybe.just(1),
        Maybe.just(8),
        Maybe.just(10),
        Maybe.just(15),
        Maybe.nothing()
      ]

      target = Maybe.just(10)

      result = Enum.filter(list, Utils.to_predicate(target, within_5_eq_maybe()))
      assert result == [Maybe.just(8), Maybe.just(10), Maybe.just(15)]
    end

    test "returns an empty list if no elements are within 5 units of target Just number" do
      list = [Maybe.just(1), Maybe.just(3), Maybe.just(20), Maybe.nothing()]
      target = Maybe.just(10)

      result = Enum.filter(list, Utils.to_predicate(target, within_5_eq_maybe()))

      assert result == []
    end

    test "ignores Nothing values when filtering" do
      list = [
        Maybe.just(10),
        Maybe.just(2),
        Maybe.nothing(),
        Maybe.just(12),
        Maybe.just(15)
      ]

      target = Maybe.just(10)
      result = Enum.filter(list, Utils.to_predicate(target, within_5_eq_maybe()))

      assert result == [Maybe.just(10), Maybe.just(12), Maybe.just(15)]
    end
  end
end
