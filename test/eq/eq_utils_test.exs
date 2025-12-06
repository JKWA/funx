defmodule Funx.Eq.UtilsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Funx.Filterable, only: [filter: 2]
  alias Funx.Eq.Utils
  alias Funx.Monad.Maybe
  alias Funx.Optics.Lens
  alias Funx.Test.Person

  doctest Funx.Eq.Utils

  describe "contramap/2" do
    test "applies the function before comparing values using eq?" do
      eq_by_length = Utils.contramap(&String.length/1)

      assert eq_by_length.eq?.("short_a", "short_b") == true
      assert eq_by_length.eq?.("short", "longer") == false
    end
  end

  describe "contramap/2 with lens" do
    test "uses lens.get as the projection" do
      lens = Lens.key(:age)
      eq = Utils.contramap(lens)

      assert eq.eq?.(%{age: 20}, %{age: 20})
      refute eq.eq?.(%{age: 20}, %{age: 21})
    end
  end

  describe "contramap/2 with atom (auto-lensed)" do
    test "treats atom as Lens.key/1" do
      eq = Utils.contramap(:age)

      assert eq.eq?.(%{age: 30}, %{age: 30})
      refute eq.eq?.(%{age: 30}, %{age: 31})
    end
  end

  describe "contramap/2 with path (auto-lensed)" do
    test "treats list as Lens.path/1" do
      eq = Utils.contramap([:stats, :wins])

      assert eq.eq?.(%{stats: %{wins: 2}}, %{stats: %{wins: 2}})
      refute eq.eq?.(%{stats: %{wins: 2}}, %{stats: %{wins: 3}})
    end
  end

  describe "contramap/2 with not_eq?/2" do
    test "applies the function before comparing values using not_eq?" do
      eq_by_length = Utils.contramap(&String.length/1)

      assert eq_by_length.not_eq?.("short_a", "short_b") == false
      assert eq_by_length.not_eq?.("short", "longer") == true
    end
  end

  describe "eq?/3" do
    test "uses the default Eq module to check equality" do
      # Assuming `Eq` defaults to simple equality comparison
      assert Utils.eq?(1, 1) == true
      assert Utils.eq?(1, 2) == false
    end

    test "uses a custom module for equality check" do
      defmodule MockEq do
        def eq?(a, b), do: a === b
      end

      assert Utils.eq?(1, 1, MockEq) == true
      assert Utils.eq?(1, 2, MockEq) == false
    end

    test "uses a custom map with an eq? function for equality check" do
      custom_eq = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      assert Utils.eq?("Alice", "ALICE", custom_eq) == true
      assert Utils.eq?("Alice", "Bob", custom_eq) == false
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

    test "checks equality using a custom eq? map function" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      custom_eq = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      assert Utils.eq_by?(& &1.name, person1, person2, custom_eq) == true
      assert Utils.eq_by?(& &1.name, person1, person3, custom_eq) == false
    end
  end

  describe "eq_by?/4 with lens" do
    test "applies Lens.get(struct, lens) for comparison" do
      lens = Lens.key(:score)
      a = %{score: 5}
      b = %{score: 5}
      c = %{score: 7}

      assert Utils.eq_by?(lens, a, b)
      refute Utils.eq_by?(lens, a, c)
    end
  end

  describe "eq_by?/4 with atom (auto-lensed)" do
    test "treats atom as Lens.key/1" do
      a = %{age: 40}
      b = %{age: 40}
      c = %{age: 41}

      assert Utils.eq_by?(:age, a, b)
      refute Utils.eq_by?(:age, a, c)
    end
  end

  describe "eq_by?/4 with path (auto-lensed)" do
    test "treats list as Lens.path/1" do
      a = %{stats: %{wins: 2}}
      b = %{stats: %{wins: 2}}
      c = %{stats: %{wins: 3}}

      assert Utils.eq_by?([:stats, :wins], a, b)
      refute Utils.eq_by?([:stats, :wins], a, c)
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
      eq?: fn a, b -> a.name == b.name and a.age == b.age end,
      not_eq?: fn a, b -> not (a.name == b.name and a.age == b.age) end
    }
  end

  describe "contramap/2 with custom Eq" do
    test "applies the function before comparing full maps with custom eq?" do
      eq_with_custom = Utils.contramap(& &1, custom_eq())

      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 30}
      person3 = %{name: "Alice", age: 25}

      assert eq_with_custom.eq?.(person1, person2) == true
      assert eq_with_custom.eq?.(person1, person3) == false
    end
  end

  describe "contramap/2 with custom Eq and not_eq?" do
    test "applies the function before comparing full maps with custom not_eq?" do
      eq_with_custom = Utils.contramap(& &1, custom_eq())

      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 30}
      person3 = %{name: "Alice", age: 25}

      assert eq_with_custom[:not_eq?].(person1, person2) == false
      assert eq_with_custom[:not_eq?].(person1, person3) == true
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
      eq?: fn a, b -> abs(a - b) <= 5 end,
      not_eq?: fn a, b -> not within_5_eq().eq?.(a, b) end
    }
  end

  describe "to_predicate/2 with custom within_5_eq" do
    test "filters elements within 5 units of target number" do
      list = [1, 2, 3, 8, 10, 15, 20]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == [8, 10, 15]
    end

    test "returns an empty list if no elements are within 5 units of target number" do
      list = [1, 2, 3, 20, 25]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == []
    end

    test "includes all elements if all are within 5 units of target number" do
      list = [7, 8, 10, 12, 14]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, within_5_eq()))

      assert result == [7, 8, 10, 12, 14]
    end
  end

  def within_5_eq_maybe do
    %{
      eq?: fn
        %Maybe.Just{value: a}, %Maybe.Just{value: b} -> abs(a - b) <= 5
        _, _ -> false
      end,
      not_eq?: fn a, b -> not within_5_eq_maybe().eq?.(a, b) end
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

      result = filter(list, Utils.to_predicate(target, within_5_eq_maybe()))
      assert result == [Maybe.just(8), Maybe.just(10), Maybe.just(15)]
    end

    test "returns an empty list if no elements are within 5 units of target Just number" do
      list = [Maybe.just(1), Maybe.just(3), Maybe.just(20), Maybe.nothing()]
      target = Maybe.just(10)

      result = filter(list, Utils.to_predicate(target, within_5_eq_maybe()))

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
      result = filter(list, Utils.to_predicate(target, within_5_eq_maybe()))

      assert result == [Maybe.just(10), Maybe.just(12), Maybe.just(15)]
    end
  end

  defmodule Within5Eq do
    @moduledoc false
    def eq?(a, b), do: abs(a - b) <= 5
  end

  describe "to_predicate/2 with module-based equality" do
    test "filters elements within 5 units of target number" do
      list = [1, 2, 3, 8, 10, 15, 20]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, Within5Eq))

      assert result == [8, 10, 15]
    end

    test "returns an empty list if no elements are within 5 units of target number" do
      list = [1, 2, 3, 20, 25]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, Within5Eq))

      assert result == []
    end

    test "includes all elements if all are within 5 units of target number" do
      list = [7, 8, 10, 12, 14]
      target_number = 10

      result = filter(list, Utils.to_predicate(target_number, Within5Eq))

      assert result == [7, 8, 10, 12, 14]
    end
  end

  defp eq_name, do: Utils.contramap(& &1.name)
  defp eq_age, do: Utils.contramap(& &1.age)
  defp eq_all, do: Utils.append_all(eq_name(), eq_age())
  defp eq_any, do: Utils.append_any(eq_name(), eq_age())

  describe "Eq Monoid" do
    test "append with equal persons" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 30}

      assert Utils.eq?(alice1, alice2, eq_name())
      assert Utils.eq?(alice1, alice2, eq_age())
      assert Utils.eq?(alice1, alice2, eq_all())
      assert Utils.eq?(alice1, alice2, eq_any())

      refute Utils.not_eq?(alice1, alice2, eq_name())
      refute Utils.not_eq?(alice1, alice2, eq_age())
      refute Utils.not_eq?(alice1, alice2, eq_all())
      refute Utils.not_eq?(alice1, alice2, eq_any())
    end

    test "append with not equal persons" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 29}

      assert Utils.eq?(alice1, alice2, eq_name())
      refute Utils.eq?(alice1, alice2, eq_age())
      refute Utils.eq?(alice1, alice2, eq_all())
      assert Utils.eq?(alice1, alice2, eq_any())

      refute Utils.not_eq?(alice1, alice2, eq_name())
      assert Utils.not_eq?(alice1, alice2, eq_age())
      assert Utils.not_eq?(alice1, alice2, eq_all())
      refute Utils.not_eq?(alice1, alice2, eq_any())
    end
  end

  defp eq_concat_all, do: Utils.concat_all([eq_name(), eq_age()])
  defp eq_concat_any, do: Utils.concat_any([eq_name(), eq_age()])

  defp eq_concat_all_default, do: Utils.concat_all([Funx.Eq])
  defp eq_concat_any_default, do: Utils.concat_any([Funx.Eq])

  test "concat with equal persons" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 30}

    assert Utils.eq?(alice1, alice2, eq_name())
    assert Utils.eq?(alice1, alice2, eq_age())
    assert Utils.eq?(alice1, alice2, eq_concat_all())
    assert Utils.eq?(alice1, alice2, eq_concat_any())

    refute Utils.not_eq?(alice1, alice2, eq_name())
    refute Utils.not_eq?(alice1, alice2, eq_age())
    refute Utils.not_eq?(alice1, alice2, eq_concat_all())
    refute Utils.not_eq?(alice1, alice2, eq_concat_any())
  end

  test "concat with not equal persons" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}

    assert Utils.eq?(alice1, alice2, eq_name())
    refute Utils.eq?(alice1, alice2, eq_age())
    refute Utils.eq?(alice1, alice2, eq_concat_all())
    assert Utils.eq?(alice1, alice2, eq_concat_any())

    refute Utils.not_eq?(alice1, alice2, eq_name())
    assert Utils.not_eq?(alice1, alice2, eq_age())
    assert Utils.not_eq?(alice1, alice2, eq_concat_all())
    refute Utils.not_eq?(alice1, alice2, eq_concat_any())
  end

  test "concat all with default (name)" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}
    bob = %Person{name: "Bob", age: 30}

    assert Utils.eq?(alice1, alice2, eq_concat_all_default())
    refute Utils.eq?(alice1, bob, eq_concat_all_default())

    refute Utils.not_eq?(alice1, alice2, eq_concat_all_default())
    assert Utils.not_eq?(alice1, bob, eq_concat_all_default())
  end

  test "concat any with default (name)" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}
    bob = %Person{name: "Bob", age: 30}

    assert Utils.eq?(alice1, alice2, eq_concat_any_default())
    refute Utils.eq?(alice1, bob, eq_concat_any_default())

    refute Utils.not_eq?(alice1, alice2, eq_concat_any_default())
    assert Utils.not_eq?(alice1, bob, eq_concat_any_default())
  end
end
