defmodule Funx.EqTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Funx.Filterable, only: [filter: 2]
  alias Funx.Monad.Maybe
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Optics.Traversal
  alias Funx.Test.Person

  doctest Funx.Eq

  describe "contramap/2" do
    test "applies the function before comparing values using eq?" do
      eq_by_length = Funx.Eq.contramap(&String.length/1)

      assert eq_by_length.eq?.("short_a", "short_b") == true
      assert eq_by_length.eq?.("short", "longer") == false
    end
  end

  describe "contramap/2 with lens" do
    test "uses lens.get as the projection" do
      lens = Lens.key(:age)
      eq = Funx.Eq.contramap(lens)

      assert eq.eq?.(%{age: 20}, %{age: 20})
      refute eq.eq?.(%{age: 20}, %{age: 21})
    end
  end

  describe "contramap/2 with prism and default" do
    test "uses prism with default for partial access" do
      alias Funx.Optics.Prism

      prism = Prism.key(:score)
      eq = Funx.Eq.contramap({prism, 0})

      # Both have score
      assert eq.eq?.(%{score: 10}, %{score: 10})
      refute eq.eq?.(%{score: 10}, %{score: 20})

      # One missing, uses default
      assert eq.eq?.(%{}, %{score: 0})
      assert eq.eq?.(%{score: 0}, %{})

      # Both missing, both use default
      assert eq.eq?.(%{}, %{})
    end
  end

  describe "contramap/2 with not_eq?/2" do
    test "applies the function before comparing values using not_eq?" do
      eq_by_length = Funx.Eq.contramap(&String.length/1)

      assert eq_by_length.not_eq?.("short_a", "short_b") == false
      assert eq_by_length.not_eq?.("short", "longer") == true
    end
  end

  describe "eq?/3" do
    test "uses the default Eq module to check equality" do
      # Assuming `Eq` defaults to simple equality comparison
      assert Funx.Eq.eq?(1, 1) == true
      assert Funx.Eq.eq?(1, 2) == false
    end

    test "uses a custom module for equality check" do
      defmodule MockEq do
        def eq?(a, b), do: a === b
      end

      assert Funx.Eq.eq?(1, 1, MockEq) == true
      assert Funx.Eq.eq?(1, 2, MockEq) == false
    end

    test "uses a custom map with an eq? function for equality check" do
      custom_eq = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      assert Funx.Eq.eq?("Alice", "ALICE", custom_eq) == true
      assert Funx.Eq.eq?("Alice", "Bob", custom_eq) == false
    end
  end

  describe "eq_by?/3" do
    test "checks equality of values by applying a projection function" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      assert Funx.Eq.eq_by?(& &1.name, person1, person2) == true
      assert Funx.Eq.eq_by?(& &1.name, person1, person3) == false

      assert Funx.Eq.eq_by?(& &1.age, person1, person2) == false
      assert Funx.Eq.eq_by?(& &1.age, person1, person3) == true
    end

    test "checks equality using a custom eq? map function" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      custom_eq = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      assert Funx.Eq.eq_by?(& &1.name, person1, person2, custom_eq) == true
      assert Funx.Eq.eq_by?(& &1.name, person1, person3, custom_eq) == false
    end
  end

  describe "eq_by?/4 with lens" do
    test "applies Lens.view!(struct, lens) for comparison" do
      lens = Lens.key(:score)
      a = %{score: 5}
      b = %{score: 5}
      c = %{score: 7}

      assert Funx.Eq.eq_by?(lens, a, b)
      refute Funx.Eq.eq_by?(lens, a, c)
    end
  end

  describe "eq_by?/4 with prism and default (projection)" do
    test "applies Prism.preview with default for comparison" do
      alias Funx.Optics.Prism

      prism = Prism.key(:score)

      a = %{score: 5}
      b = %{score: 5}
      c = %{score: 7}
      d = %{}

      # Both present
      assert Funx.Eq.eq_by?({prism, 0}, a, b)
      refute Funx.Eq.eq_by?({prism, 0}, a, c)

      # One missing, uses default
      refute Funx.Eq.eq_by?({prism, 0}, a, d)
      refute Funx.Eq.eq_by?({prism, 0}, d, a)

      # Both missing, both use default
      assert Funx.Eq.eq_by?({prism, 0}, d, %{})
    end
  end

  describe "eq_by?/4 with atom (auto-lensed)" do
    test "treats atom as Lens.key/1" do
      a = %{age: 40}
      b = %{age: 40}
      c = %{age: 41}

      assert Funx.Eq.eq_by?(Lens.key(:age), a, b)
      refute Funx.Eq.eq_by?(Lens.key(:age), a, c)
    end
  end

  describe "eq_by?/4 with path (auto-lensed)" do
    test "treats list as lawful lens composition" do
      a = %{stats: %{wins: 2}}
      b = %{stats: %{wins: 2}}
      c = %{stats: %{wins: 3}}

      assert Funx.Eq.eq_by?(Lens.path([:stats, :wins]), a, b)
      refute Funx.Eq.eq_by?(Lens.path([:stats, :wins]), a, c)
    end
  end

  describe "eq_by?/4 with prism and default" do
    test "uses prism with default for partial access" do
      alias Funx.Optics.Prism

      prism = Prism.key(:score)

      # Both have score
      assert Funx.Eq.eq_by?({prism, 0}, %{score: 10}, %{score: 10})
      refute Funx.Eq.eq_by?({prism, 0}, %{score: 10}, %{score: 20})

      # One missing, uses default
      assert Funx.Eq.eq_by?({prism, 0}, %{}, %{score: 0})
      assert Funx.Eq.eq_by?({prism, 0}, %{score: 0}, %{})

      # Both missing, both use default
      assert Funx.Eq.eq_by?({prism, 0}, %{}, %{})
    end
  end

  describe "not_eq?/2" do
    test "returns true if values are not equal" do
      assert Funx.Eq.not_eq?(1, 2) == true
      assert Funx.Eq.not_eq?(3, 3) == false
    end

    test "works with maps" do
      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 25}
      person3 = %{name: "Bob", age: 30}

      assert Funx.Eq.not_eq?(person1[:name], person3[:name]) == true
      assert Funx.Eq.not_eq?(person1[:name], person2[:name]) == false
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
      eq_with_custom = Funx.Eq.contramap(& &1, custom_eq())

      person1 = %{name: "Alice", age: 30}
      person2 = %{name: "Alice", age: 30}
      person3 = %{name: "Alice", age: 25}

      assert eq_with_custom.eq?.(person1, person2) == true
      assert eq_with_custom.eq?.(person1, person3) == false
    end
  end

  describe "contramap/2 with custom Eq and not_eq?" do
    test "applies the function before comparing full maps with custom not_eq?" do
      eq_with_custom = Funx.Eq.contramap(& &1, custom_eq())

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

      assert Funx.Eq.not_eq?(person1, person3, custom_eq()) == true
      assert Funx.Eq.not_eq?(person1, person2, custom_eq()) == false
      assert Funx.Eq.not_eq?(person1, person4, custom_eq()) == true
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

      result = filter(list, Funx.Eq.to_predicate(target_number, within_5_eq()))

      assert result == [8, 10, 15]
    end

    test "returns an empty list if no elements are within 5 units of target number" do
      list = [1, 2, 3, 20, 25]
      target_number = 10

      result = filter(list, Funx.Eq.to_predicate(target_number, within_5_eq()))

      assert result == []
    end

    test "includes all elements if all are within 5 units of target number" do
      list = [7, 8, 10, 12, 14]
      target_number = 10

      result = filter(list, Funx.Eq.to_predicate(target_number, within_5_eq()))

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

      result = filter(list, Funx.Eq.to_predicate(target, within_5_eq_maybe()))
      assert result == [Maybe.just(8), Maybe.just(10), Maybe.just(15)]
    end

    test "returns an empty list if no elements are within 5 units of target Just number" do
      list = [Maybe.just(1), Maybe.just(3), Maybe.just(20), Maybe.nothing()]
      target = Maybe.just(10)

      result = filter(list, Funx.Eq.to_predicate(target, within_5_eq_maybe()))

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
      result = filter(list, Funx.Eq.to_predicate(target, within_5_eq_maybe()))

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

      result = filter(list, Funx.Eq.to_predicate(target_number, Within5Eq))

      assert result == [8, 10, 15]
    end

    test "returns an empty list if no elements are within 5 units of target number" do
      list = [1, 2, 3, 20, 25]
      target_number = 10

      result = filter(list, Funx.Eq.to_predicate(target_number, Within5Eq))

      assert result == []
    end

    test "includes all elements if all are within 5 units of target number" do
      list = [7, 8, 10, 12, 14]
      target_number = 10

      result = filter(list, Funx.Eq.to_predicate(target_number, Within5Eq))

      assert result == [7, 8, 10, 12, 14]
    end
  end

  defp eq_name, do: Funx.Eq.contramap(& &1.name)
  defp eq_age, do: Funx.Eq.contramap(& &1.age)
  defp eq_all, do: Funx.Eq.append_all(eq_name(), eq_age())
  defp eq_any, do: Funx.Eq.append_any(eq_name(), eq_age())

  describe "Eq Monoid" do
    test "append with equal persons" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 30}

      assert Funx.Eq.eq?(alice1, alice2, eq_name())
      assert Funx.Eq.eq?(alice1, alice2, eq_age())
      assert Funx.Eq.eq?(alice1, alice2, eq_all())
      assert Funx.Eq.eq?(alice1, alice2, eq_any())

      refute Funx.Eq.not_eq?(alice1, alice2, eq_name())
      refute Funx.Eq.not_eq?(alice1, alice2, eq_age())
      refute Funx.Eq.not_eq?(alice1, alice2, eq_all())
      refute Funx.Eq.not_eq?(alice1, alice2, eq_any())
    end

    test "append with not equal persons" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 29}

      assert Funx.Eq.eq?(alice1, alice2, eq_name())
      refute Funx.Eq.eq?(alice1, alice2, eq_age())
      refute Funx.Eq.eq?(alice1, alice2, eq_all())
      assert Funx.Eq.eq?(alice1, alice2, eq_any())

      refute Funx.Eq.not_eq?(alice1, alice2, eq_name())
      assert Funx.Eq.not_eq?(alice1, alice2, eq_age())
      assert Funx.Eq.not_eq?(alice1, alice2, eq_all())
      refute Funx.Eq.not_eq?(alice1, alice2, eq_any())
    end
  end

  defp eq_concat_all, do: Funx.Eq.concat_all([eq_name(), eq_age()])
  defp eq_concat_any, do: Funx.Eq.concat_any([eq_name(), eq_age()])

  defp eq_concat_all_default, do: Funx.Eq.concat_all([Funx.Eq.Protocol])
  defp eq_concat_any_default, do: Funx.Eq.concat_any([Funx.Eq.Protocol])

  test "concat with equal persons" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 30}

    assert Funx.Eq.eq?(alice1, alice2, eq_name())
    assert Funx.Eq.eq?(alice1, alice2, eq_age())
    assert Funx.Eq.eq?(alice1, alice2, eq_concat_all())
    assert Funx.Eq.eq?(alice1, alice2, eq_concat_any())

    refute Funx.Eq.not_eq?(alice1, alice2, eq_name())
    refute Funx.Eq.not_eq?(alice1, alice2, eq_age())
    refute Funx.Eq.not_eq?(alice1, alice2, eq_concat_all())
    refute Funx.Eq.not_eq?(alice1, alice2, eq_concat_any())
  end

  test "concat with not equal persons" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}

    assert Funx.Eq.eq?(alice1, alice2, eq_name())
    refute Funx.Eq.eq?(alice1, alice2, eq_age())
    refute Funx.Eq.eq?(alice1, alice2, eq_concat_all())
    assert Funx.Eq.eq?(alice1, alice2, eq_concat_any())

    refute Funx.Eq.not_eq?(alice1, alice2, eq_name())
    assert Funx.Eq.not_eq?(alice1, alice2, eq_age())
    assert Funx.Eq.not_eq?(alice1, alice2, eq_concat_all())
    refute Funx.Eq.not_eq?(alice1, alice2, eq_concat_any())
  end

  test "concat all with default (name)" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}
    bob = %Person{name: "Bob", age: 30}

    assert Funx.Eq.eq?(alice1, alice2, eq_concat_all_default())
    refute Funx.Eq.eq?(alice1, bob, eq_concat_all_default())

    refute Funx.Eq.not_eq?(alice1, alice2, eq_concat_all_default())
    assert Funx.Eq.not_eq?(alice1, bob, eq_concat_all_default())
  end

  test "concat any with default (name)" do
    alice1 = %Person{name: "Alice", age: 30}
    alice2 = %Person{name: "Alice", age: 29}
    bob = %Person{name: "Bob", age: 30}

    assert Funx.Eq.eq?(alice1, alice2, eq_concat_any_default())
    refute Funx.Eq.eq?(alice1, bob, eq_concat_any_default())

    refute Funx.Eq.not_eq?(alice1, alice2, eq_concat_any_default())
    assert Funx.Eq.not_eq?(alice1, bob, eq_concat_any_default())
  end

  describe "contramap/2 with bare Prism" do
    test "Nothing equals Nothing" do
      prism = Prism.key(:ticket)
      eq = Funx.Eq.contramap(prism)

      assert Funx.Eq.eq?(%Person{ticket: nil}, %Person{ticket: nil}, eq)
    end

    test "Just equals Just when values match" do
      prism = Prism.key(:ticket)
      eq = Funx.Eq.contramap(prism)

      assert Funx.Eq.eq?(%Person{ticket: :premium}, %Person{ticket: :premium}, eq)
    end

    test "Just not equals Just when values differ" do
      prism = Prism.key(:ticket)
      eq = Funx.Eq.contramap(prism)

      refute Funx.Eq.eq?(%Person{ticket: :premium}, %Person{ticket: :basic}, eq)
    end

    test "Nothing not equals Just" do
      prism = Prism.key(:ticket)
      eq = Funx.Eq.contramap(prism)

      refute Funx.Eq.eq?(%Person{ticket: nil}, %Person{ticket: :premium}, eq)
      refute Funx.Eq.eq?(%Person{ticket: :premium}, %Person{ticket: nil}, eq)
    end

    test "not_eq? with bare Prism" do
      prism = Prism.key(:ticket)
      eq = Funx.Eq.contramap(prism)

      refute Funx.Eq.not_eq?(%Person{ticket: nil}, %Person{ticket: nil}, eq)
      refute Funx.Eq.not_eq?(%Person{ticket: :premium}, %Person{ticket: :premium}, eq)
      assert Funx.Eq.not_eq?(%Person{ticket: :premium}, %Person{ticket: :basic}, eq)
      assert Funx.Eq.not_eq?(%Person{ticket: nil}, %Person{ticket: :premium}, eq)
    end
  end

  describe "to_eq_map/1" do
    test "returns Eq map unchanged when already an Eq map" do
      eq_map = %{
        eq?: fn a, b -> a == b end,
        not_eq?: fn a, b -> a != b end
      }

      result = Funx.Eq.to_eq_map(eq_map)

      assert result == eq_map
    end

    test "converts module with eq?/2 to Eq map" do
      defmodule CustomEqModule do
        def eq?(a, b), do: a == b
        def not_eq?(a, b), do: a != b
      end

      eq_map = Funx.Eq.to_eq_map(CustomEqModule)

      assert eq_map.eq?.(42, 42)
      refute eq_map.eq?.(42, 99)
      refute eq_map.not_eq?.(42, 42)
      assert eq_map.not_eq?.(42, 99)
    end

    test "converts module without eq?/2 to Eq map using protocol" do
      # String module doesn't have eq?/2, so should use Funx.Eq protocol
      eq_map = Funx.Eq.to_eq_map(String)

      assert eq_map.eq?.("hello", "hello")
      refute eq_map.eq?.("hello", "world")
      refute eq_map.not_eq?.("hello", "hello")
      assert eq_map.not_eq?.("hello", "world")
    end

    test "protocol-based Eq map works with custom structs" do
      # Person doesn't have eq?/2, should use Funx.Eq protocol
      eq_map = Funx.Eq.to_eq_map(Person)

      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 30}

      assert eq_map.eq?.(alice1, alice2)
      refute eq_map.eq?.(alice1, bob)
    end
  end

  describe "contramap/2 with Traversal" do
    test "all foci present and all match" do
      traversal = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      eq = Funx.Eq.contramap(traversal)

      assert Funx.Eq.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 30},
               eq
             )
    end

    test "all foci present but one differs" do
      traversal = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      eq = Funx.Eq.contramap(traversal)

      refute Funx.Eq.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 25},
               eq
             )
    end

    test "all foci present but all differ" do
      traversal = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      eq = Funx.Eq.contramap(traversal)

      refute Funx.Eq.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Bob", age: 25},
               eq
             )
    end

    test "one structure missing a focus" do
      traversal = Traversal.combine([Prism.key(:name), Prism.key(:missing)])
      eq = Funx.Eq.contramap(traversal)

      refute Funx.Eq.eq?(
               %Person{name: "Alice"},
               %Person{name: "Alice"},
               eq
             )
    end

    test "both structures missing the same focus" do
      traversal = Traversal.combine([Prism.key(:name), Prism.key(:missing)])
      eq = Funx.Eq.contramap(traversal)

      refute Funx.Eq.eq?(
               %Person{name: "Alice"},
               %Person{name: "Bob"},
               eq
             )
    end

    test "not_eq? with all foci matching" do
      traversal = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      eq = Funx.Eq.contramap(traversal)

      refute Funx.Eq.not_eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 30},
               eq
             )
    end

    test "not_eq? with one focus differing" do
      traversal = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      eq = Funx.Eq.contramap(traversal)

      assert Funx.Eq.not_eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 25},
               eq
             )
    end

    test "not_eq? with missing focus" do
      traversal = Traversal.combine([Prism.key(:name), Prism.key(:missing)])
      eq = Funx.Eq.contramap(traversal)

      assert Funx.Eq.not_eq?(
               %Person{name: "Alice"},
               %Person{name: "Alice"},
               eq
             )
    end
  end
end
