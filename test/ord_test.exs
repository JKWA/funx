defmodule Funx.OrdTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Kernel, except: [min: 2, max: 2]
  import Funx.Ord

  alias Funx.Monad.{Either, Identity, Maybe}
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Ord.Any
  alias Funx.Test.Person

  doctest Funx.Ord

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp ord_name, do: contramap(& &1.name)
  defp ord_age, do: contramap(& &1.age)
  defp ord_ticket, do: contramap(& &1.ticket)

  defp ord_compose_2, do: compose(ord_name(), ord_age())
  defp ord_compose_list, do: compose([ord_name(), ord_age()])
  defp ord_compose_age, do: compose([ord_age(), ord_ticket(), Funx.Ord.Protocol])
  defp ord_compose_default, do: compose([Funx.Ord.Protocol])
  defp ord_compose_empty, do: compose([])

  # ============================================================================
  # Basic Operations Tests
  # ============================================================================

  describe "compare/3" do
    test "returns :lt if the first value is less than the second" do
      assert Maybe.just(3) |> compare(Maybe.just(5)) == :lt
    end

    test "returns :eq if the two values are equal" do
      assert Either.right(5) |> compare(Either.right(5)) == :eq
    end

    test "returns :gt if the first value is greater than the second" do
      assert Identity.pure(7) |> compare(Identity.pure(5)) == :gt
    end
  end

  describe "max/3" do
    test "returns the maximum of two values" do
      assert max(Maybe.just(10), Maybe.just(20)) == Maybe.just(20)
      assert max(Either.right(20), Either.right(10)) == Either.right(20)
    end
  end

  describe "min/3" do
    test "returns the minimum of two values" do
      assert min(Identity.pure(10), Identity.pure(20)) == Identity.pure(10)
      assert min(Maybe.just(20), Maybe.just(10)) == Maybe.just(10)
    end
  end

  describe "clamp/4" do
    test "returns the value if within the range" do
      assert Maybe.just(10) |> clamp(Maybe.just(5), Maybe.just(15)) == Maybe.just(10)
    end

    test "returns min if value is below range" do
      assert Either.right(3) |> clamp(Either.right(5), Either.right(15)) == Either.right(5)
    end

    test "returns max if value is above range" do
      assert Identity.pure(20) |> clamp(Identity.pure(5), Identity.pure(15)) ==
               Identity.pure(15)
    end
  end

  describe "between/4" do
    test "returns true if value is within the range" do
      assert Maybe.just(10) |> between(Maybe.just(5), Maybe.just(15))
    end

    test "returns false if value is below the range" do
      refute Either.right(3) |> between(Either.right(5), Either.right(15))
    end

    test "returns false if value is above the range" do
      refute Identity.pure(20) |> between(Identity.pure(5), Identity.pure(15))
    end
  end

  # ============================================================================
  # Contramap Tests
  # ============================================================================

  describe "contramap/2 with function" do
    setup do
      {:ok, string_length: contramap(&String.length/1)}
    end

    test "compares 'banana' and 'apple' by length", %{string_length: string_length} do
      assert string_length.lt?.("banana", "apple") == false
      assert string_length.lt?.("apple", "banana") == true
    end

    test "returns the maximum of two strings by length", %{string_length: string_length} do
      assert max("banana", "apple", string_length) == "banana"
    end

    test "returns the minimum of two strings by length", %{string_length: string_length} do
      assert min("banana", "apple", string_length) == "apple"
    end

    test "clamps a value between 'apple' and 'cantaloupe' by length", %{
      string_length: string_length
    } do
      assert clamp("banana", "apple", "cantaloupe", string_length) == "banana"
      assert clamp("berry", "apple", "cantaloupe", string_length) == "berry"
      assert clamp("watermelon", "apple", "cantaloupe", string_length) == "watermelon"
    end

    test "checks if 'banana' is between 'apple' and 'cantaloupe' by length", %{
      string_length: string_length
    } do
      assert between("banana", "apple", "cantaloupe", string_length) == true
      assert between("berry", "banana", "cantaloupe", string_length) == false
    end

    test "compares two strings by length and returns :lt, :eq, or :gt", %{
      string_length: string_length
    } do
      assert compare("banana", "apple", string_length) == :gt
      assert compare("apple", "banana", string_length) == :lt
      assert compare("pear", "bear", string_length) == :eq
    end
  end

  describe "contramap/2 with composed function" do
    test "compares tuples by name length using two composed contramaps" do
      tuple_name_length = contramap(&(&1 |> elem(0) |> String.length()))

      assert compare({"banana", 6}, {"apple", 5}, tuple_name_length) == :gt
      assert compare({"pear", 4}, {"peach", 5}, tuple_name_length) == :lt
      assert compare({"grape", 5}, {"peach", 5}, tuple_name_length) == :eq
    end
  end

  describe "contramap/2 with custom ord map" do
    setup do
      ord_map = %{
        lt?: &Kernel.<(&1, &2),
        le?: &Kernel.<=(&1, &2),
        gt?: &Kernel.>(&1, &2),
        ge?: &Kernel.>=(&1, &2)
      }

      {:ok, string_length: contramap(&String.length/1, ord_map)}
    end

    test "compares 'banana' and 'apple' by length", %{string_length: string_length} do
      assert string_length.lt?.("banana", "apple") == false
      assert string_length.lt?.("apple", "banana") == true
      assert string_length.gt?.("banana", "apple") == true
      assert string_length.gt?.("apple", "banana") == false
      assert string_length.ge?.("banana", "apple") == true
      assert string_length.ge?.("apple", "banana") == false
      assert string_length.ge?.("apple", "apple") == true
      assert string_length.le?.("banana", "apple") == false
      assert string_length.le?.("apple", "banana") == true
      assert string_length.le?.("apple", "apple") == true
    end

    test "returns the maximum of two strings by length", %{string_length: string_length} do
      assert max("banana", "apple", string_length) == "banana"
    end

    test "returns the minimum of two strings by length", %{string_length: string_length} do
      assert min("banana", "apple", string_length) == "apple"
    end

    test "clamps a value between 'apple' and 'cantaloupe' by length", %{
      string_length: string_length
    } do
      assert clamp("banana", "apple", "cantaloupe", string_length) == "banana"
      assert clamp("berry", "apple", "cantaloupe", string_length) == "berry"
      assert clamp("watermelon", "apple", "cantaloupe", string_length) == "watermelon"
    end

    test "checks if 'banana' is between 'apple' and 'cantaloupe' by length", %{
      string_length: string_length
    } do
      assert between("banana", "apple", "cantaloupe", string_length) == true
      assert between("berry", "banana", "cantaloupe", string_length) == false
    end

    test "compares two strings by length and returns :lt, :eq, or :gt", %{
      string_length: string_length
    } do
      assert compare("banana", "apple", string_length) == :gt
      assert compare("apple", "banana", string_length) == :lt
      assert compare("pear", "bear", string_length) == :eq
    end
  end

  describe "contramap/2 with lens" do
    test "compares maps using a lens for a single key" do
      lens = Lens.key(:age)
      ord = contramap(lens)

      assert ord.lt?.(%{age: 30}, %{age: 40})
      assert ord.gt?.(%{age: 50}, %{age: 20})
      assert ord.le?.(%{age: 25}, %{age: 25})
      assert ord.ge?.(%{age: 25}, %{age: 25})
    end

    test "compares maps using a nested lens path" do
      lens = Lens.compose([Lens.key(:stats), Lens.key(:wins)])
      ord = contramap(lens)

      assert ord.lt?.(%{stats: %{wins: 2}}, %{stats: %{wins: 5}})
      assert ord.gt?.(%{stats: %{wins: 7}}, %{stats: %{wins: 3}})
      assert ord.le?.(%{stats: %{wins: 4}}, %{stats: %{wins: 4}})
    end
  end

  describe "contramap/2 with prism and default" do
    test "orders values using prism with default for partial access" do
      prism = Prism.key(:score)
      ord = contramap({prism, 0})

      # Both have score
      assert ord.lt?.(%{score: 10}, %{score: 20})
      assert ord.gt?.(%{score: 50}, %{score: 30})
      assert ord.le?.(%{score: 25}, %{score: 25})
      assert ord.ge?.(%{score: 25}, %{score: 25})

      # One missing, uses default (0)
      # 0 <= 5
      assert ord.le?.(%{}, %{score: 5})
      # 10 >= 0
      assert ord.ge?.(%{score: 10}, %{})

      # Both missing, both use default (0 vs 0)
      assert ord.le?.(%{}, %{})
      assert ord.ge?.(%{}, %{})
    end
  end

  describe "contramap/2 with bare prism (Maybe.lift_ord)" do
    test "orders values using bare prism with Nothing < Just semantics" do
      prism = Prism.key(:score)
      ord = contramap(prism)

      # Both have score - Just(10) < Just(20)
      assert ord.lt?.(%{score: 10}, %{score: 20})
      assert ord.gt?.(%{score: 50}, %{score: 30})
      assert ord.le?.(%{score: 25}, %{score: 25})
      assert ord.ge?.(%{score: 25}, %{score: 25})

      # Nothing < Just - missing value sorts before present value
      assert ord.lt?.(%{}, %{score: 5})
      assert ord.le?.(%{}, %{score: 5})
      refute ord.gt?.(%{}, %{score: 5})
      refute ord.ge?.(%{}, %{score: 5})

      # Just > Nothing - present value sorts after missing value
      assert ord.gt?.(%{score: 10}, %{})
      assert ord.ge?.(%{score: 10}, %{})
      refute ord.lt?.(%{score: 10}, %{})
      refute ord.le?.(%{score: 10}, %{})

      # Both missing - Nothing == Nothing
      assert ord.le?.(%{}, %{})
      assert ord.ge?.(%{}, %{})
      refute ord.lt?.(%{}, %{})
      refute ord.gt?.(%{}, %{})
    end

    test "bare prism with nested path" do
      prism = Prism.path([:stats, :wins])
      ord = contramap(prism)

      # Both have nested value
      assert ord.lt?.(%{stats: %{wins: 2}}, %{stats: %{wins: 5}})
      assert ord.gt?.(%{stats: %{wins: 7}}, %{stats: %{wins: 3}})

      # One missing intermediate value (Nothing < Just)
      assert ord.lt?.(%{stats: %{}}, %{stats: %{wins: 5}})
      assert ord.gt?.(%{stats: %{wins: 5}}, %{stats: %{}})

      # One completely missing stats (Nothing < Just)
      assert ord.lt?.(%{}, %{stats: %{wins: 5}})
      assert ord.gt?.(%{stats: %{wins: 5}}, %{})
    end

    test "compare function returns :lt, :eq, :gt with bare prism" do
      prism = Prism.key(:score)
      ord = contramap(prism)

      # Just vs Just
      assert compare(%{score: 10}, %{score: 20}, ord) == :lt
      assert compare(%{score: 20}, %{score: 10}, ord) == :gt
      assert compare(%{score: 15}, %{score: 15}, ord) == :eq

      # Nothing vs Just
      assert compare(%{}, %{score: 10}, ord) == :lt

      # Just vs Nothing
      assert compare(%{score: 10}, %{}, ord) == :gt

      # Nothing vs Nothing
      assert compare(%{}, %{}, ord) == :eq
    end
  end

  # ============================================================================
  # Utility Functions Tests
  # ============================================================================

  describe "reverse/1 with protocol" do
    test "reverses the ordering logic" do
      rev_ord = reverse()

      assert rev_ord.gt?.(Maybe.just(10), Maybe.just(5)) ==
               Any.lt?(Maybe.just(10), Maybe.just(5))

      assert rev_ord.lt?.(Either.right(5), Either.right(10)) ==
               Any.gt?(Either.right(5), Either.right(10))

      assert rev_ord.le?.(Identity.pure(10), Identity.pure(10)) ==
               Any.ge?(Identity.pure(10), Identity.pure(10))

      assert rev_ord.ge?.(Maybe.just(5), Maybe.just(5)) ==
               Any.le?(Maybe.just(5), Maybe.just(5))
    end
  end

  describe "reverse/1 with ord map" do
    test "reverses the ordering logic" do
      ord_map = %{
        lt?: &Kernel.<(&1, &2),
        le?: &Kernel.<=(&1, &2),
        gt?: &Kernel.>(&1, &2),
        ge?: &Kernel.>=(&1, &2)
      }

      rev_ord = reverse(ord_map)

      assert rev_ord.gt?.(Maybe.just(10), Maybe.just(5)) ==
               Any.lt?(Maybe.just(10), Maybe.just(5))

      assert rev_ord.lt?.(Either.right(5), Either.right(10)) ==
               Any.gt?(Either.right(5), Either.right(10))

      assert rev_ord.le?.(Identity.pure(10), Identity.pure(10)) ==
               Any.ge?(Identity.pure(10), Identity.pure(10))

      assert rev_ord.ge?.(Maybe.just(5), Maybe.just(5)) ==
               Any.le?(Maybe.just(5), Maybe.just(5))
    end
  end

  describe "comparator/1 with Any Ord" do
    test "compares plain numbers" do
      assert comparator(Any).(5, 10)
      refute comparator(Any).(10, 5)
      assert comparator(Any).(10, 10)
    end
  end

  describe "to_eq/1" do
    test "eq with identical values" do
      assert to_eq().eq?.(:apple, :apple)
      assert to_eq().eq?.(1, 1)
      assert to_eq().eq?.("test", "test")
    end

    test "not eq different values" do
      assert to_eq().not_eq?.(:apple, :banana)
      assert to_eq().not_eq?.(1, 2)
      assert to_eq().not_eq?.("test", "different")
    end
  end

  # ============================================================================
  # Monoid Operations Tests
  # ============================================================================

  describe "Ord Monoid - deprecated append/concat" do
    test "append/2 delegates to compose/2" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      combined = append(ord_name(), ord_age())
      assert compare(alice, bob, combined) == :lt
    end

    test "concat/1 delegates to compose/1" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      combined = concat([ord_name(), ord_age()])
      assert compare(alice, bob, combined) == :lt
    end
  end

  describe "Ord Monoid - compose" do
    test "compose/2 combines two orderings" do
      alice = %Person{name: "Alice", age: 30, ticket: :b}
      bob = %Person{name: "Bob", age: 25, ticket: :a}

      assert compare(alice, bob, ord_compose_2()) == :lt
      assert compare(bob, alice, ord_compose_2()) == :gt
      assert compare(alice, alice, ord_compose_2()) == :eq
    end

    test "compose/1 with list combines orderings lexicographically" do
      alice = %Person{name: "Alice", age: 30, ticket: :b}
      bob = %Person{name: "Bob", age: 25, ticket: :a}
      bob_b = %Person{name: "Bob", age: 30, ticket: :a}
      bob_c = %Person{name: "Bob", age: 30, ticket: :b}

      assert compare(alice, bob, ord_compose_list()) == :lt
      assert compare(bob, alice, ord_compose_list()) == :gt
      assert compare(alice, alice, ord_compose_list()) == :eq

      assert compare(alice, bob, ord_compose_age()) == :gt
      assert compare(bob, alice, ord_compose_age()) == :lt
      assert compare(alice, alice, ord_compose_age()) == :eq
      assert compare(alice, bob_b, ord_compose_age()) == :gt
      assert compare(alice, bob_c, ord_compose_age()) == :lt

      assert ord_compose_list().lt?.(alice, bob)
      assert ord_compose_list().le?.(alice, alice)
      assert ord_compose_list().gt?.(bob, alice)
      assert ord_compose_list().ge?.(bob, alice)
    end

    test "compose/1 with empty list makes everything equal" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      assert compare(alice, bob, ord_compose_empty()) == :eq
      assert compare(bob, alice, ord_compose_empty()) == :eq
      assert compare(alice, alice, ord_compose_empty()) == :eq
    end

    test "compose/1 with default ord (name)" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      assert compare(alice, bob, ord_compose_default()) == :lt
      assert compare(bob, alice, ord_compose_default()) == :gt
      assert compare(alice, alice, ord_compose_default()) == :eq
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: total order laws" do
    property "totality: every pair compares as :lt, :eq, or :gt" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        result = compare(a, b)
        assert result in [:lt, :eq, :gt]
      end
    end

    property "antisymmetry: if lt?(a, b) then not lt?(b, a)" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)

        if ord.lt?.(a, b) do
          refute ord.lt?.(b, a)
        end
      end
    end

    property "transitivity: if lt?(a, b) and lt?(b, c) then lt?(a, c)" do
      check all(
              a <- integer(),
              b <- integer(),
              c <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)

        if ord.lt?.(a, b) and ord.lt?.(b, c) do
          assert ord.lt?.(a, c)
        end
      end
    end

    property "comparison consistency: compare(a, b) == :lt iff lt?(a, b)" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)

        assert compare(a, b) == :lt == ord.lt?.(a, b)
        assert compare(a, b) == :gt == ord.gt?.(a, b)
        assert compare(a, b) == :eq == (not ord.lt?.(a, b) and not ord.gt?.(a, b))
      end
    end

    property "le? and ge? consistency with lt? and gt?" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)

        # le? means lt? or eq
        assert ord.le?.(a, b) == (ord.lt?.(a, b) or compare(a, b) == :eq)
        # ge? means gt? or eq
        assert ord.ge?.(a, b) == (ord.gt?.(a, b) or compare(a, b) == :eq)
      end
    end
  end

  describe "property: contramap preservation" do
    property "contramap preserves ordering for functions" do
      check all(
              a <- string(:alphanumeric, min_length: 1),
              b <- string(:alphanumeric, min_length: 1)
            ) do
        ord_by_length = contramap(&String.length/1)

        len_a = String.length(a)
        len_b = String.length(b)

        cond do
          len_a < len_b -> assert ord_by_length.lt?.(a, b)
          len_a > len_b -> assert ord_by_length.gt?.(a, b)
          len_a == len_b -> assert ord_by_length.le?.(a, b) and ord_by_length.ge?.(a, b)
        end
      end
    end

    property "contramap with lens preserves ordering" do
      check all(
              age1 <- integer(1..100),
              age2 <- integer(1..100)
            ) do
        lens = Lens.key(:age)
        ord = contramap(lens)

        map1 = %{age: age1}
        map2 = %{age: age2}

        cond do
          age1 < age2 -> assert ord.lt?.(map1, map2)
          age1 > age2 -> assert ord.gt?.(map1, map2)
          age1 == age2 -> assert compare(map1, map2, ord) == :eq
        end
      end
    end

    property "contramap with prism and default preserves ordering" do
      check all(
              score1 <- one_of([constant(nil), integer(0..100)]),
              score2 <- one_of([constant(nil), integer(0..100)])
            ) do
        prism = Prism.key(:score)
        ord = contramap({prism, 0})

        map1 = if score1, do: %{score: score1}, else: %{}
        map2 = if score2, do: %{score: score2}, else: %{}

        # Both nil maps to 0, compare effective values
        effective1 = score1 || 0
        effective2 = score2 || 0

        cond do
          effective1 < effective2 -> assert ord.lt?.(map1, map2)
          effective1 > effective2 -> assert ord.gt?.(map1, map2)
          effective1 == effective2 -> assert compare(map1, map2, ord) == :eq
        end
      end
    end

    property "contramap with bare prism: Nothing < Just" do
      check all(
              score1 <- one_of([constant(nil), integer(1..100)]),
              score2 <- one_of([constant(nil), integer(1..100)])
            ) do
        prism = Prism.key(:score)
        ord = contramap(prism)

        map1 = if score1, do: %{score: score1}, else: %{}
        map2 = if score2, do: %{score: score2}, else: %{}

        cond do
          # Both nil - Nothing == Nothing
          is_nil(score1) and is_nil(score2) ->
            assert compare(map1, map2, ord) == :eq

          # First nil, second present - Nothing < Just
          is_nil(score1) and not is_nil(score2) ->
            assert ord.lt?.(map1, map2)

          # First present, second nil - Just > Nothing
          not is_nil(score1) and is_nil(score2) ->
            assert ord.gt?.(map1, map2)

          # Both present - compare values
          true ->
            cond do
              score1 < score2 -> assert ord.lt?.(map1, map2)
              score1 > score2 -> assert ord.gt?.(map1, map2)
              score1 == score2 -> assert compare(map1, map2, ord) == :eq
            end
        end
      end
    end
  end

  describe "property: reverse laws" do
    property "reverse swaps lt? and gt?" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)
        rev_ord = reverse()

        assert ord.lt?.(a, b) == rev_ord.gt?.(a, b)
        assert ord.gt?.(a, b) == rev_ord.lt?.(a, b)
        assert ord.le?.(a, b) == rev_ord.ge?.(a, b)
        assert ord.ge?.(a, b) == rev_ord.le?.(a, b)
      end
    end

    property "double reverse is identity" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        ord = to_ord_map(Funx.Ord.Protocol)
        double_reversed = reverse(reverse())

        assert ord.lt?.(a, b) == double_reversed.lt?.(a, b)
        assert ord.gt?.(a, b) == double_reversed.gt?.(a, b)
      end
    end
  end

  describe "property: utility functions" do
    property "max returns the larger value" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        result = max(a, b)

        cond do
          a > b -> assert result == a
          a < b -> assert result == b
          a == b -> assert result == a
        end
      end
    end

    property "min returns the smaller value" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        result = min(a, b)

        cond do
          a < b -> assert result == a
          a > b -> assert result == b
          a == b -> assert result == a
        end
      end
    end

    property "clamp constrains value to range" do
      check all(
              value <- integer(),
              bounds <- uniq_list_of(integer(), length: 2)
            ) do
        [min_val, max_val] = Enum.sort(bounds)

        result = clamp(value, min_val, max_val)

        assert result >= min_val
        assert result <= max_val

        cond do
          value < min_val -> assert result == min_val
          value > max_val -> assert result == max_val
          true -> assert result == value
        end
      end
    end

    property "between checks range inclusion" do
      check all(
              value <- integer(),
              bounds <- uniq_list_of(integer(), length: 2)
            ) do
        [min_val, max_val] = Enum.sort(bounds)

        result = between(value, min_val, max_val)

        if value >= min_val and value <= max_val do
          assert result
        else
          refute result
        end
      end
    end

    property "comparator returns consistent results" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        comp = comparator(Funx.Ord.Protocol)

        # comparator returns true if a <= b
        if a <= b do
          assert comp.(a, b)
        else
          refute comp.(a, b)
        end
      end
    end

    property "to_eq creates consistent equality comparator" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        eq = to_eq()

        if a == b do
          assert eq.eq?.(a, b)
          refute eq.not_eq?.(a, b)
        else
          refute eq.eq?.(a, b)
          assert eq.not_eq?.(a, b)
        end
      end
    end
  end

  describe "property: monoid laws" do
    property "compose/1 with empty list is identity (all equal)" do
      check all(
              a <- integer(),
              b <- integer()
            ) do
        empty_ord = compose([])

        # Empty compose makes everything equal
        assert compare(a, b, empty_ord) == :eq
      end
    end

    property "compose/1 combines orderings lexicographically" do
      check all(
              name1 <- string(:alphanumeric, min_length: 1),
              name2 <- string(:alphanumeric, min_length: 1),
              age1 <- integer(1..100),
              age2 <- integer(1..100)
            ) do
        ord_name = contramap(& &1.name)
        ord_age = contramap(& &1.age)
        combined = compose([ord_name, ord_age])

        person1 = %{name: name1, age: age1}
        person2 = %{name: name2, age: age2}

        cond do
          # Names differ - ordering determined by name
          name1 < name2 ->
            assert combined.lt?.(person1, person2)

          name1 > name2 ->
            assert combined.gt?.(person1, person2)

          # Names equal - ordering determined by age
          name1 == name2 and age1 < age2 ->
            assert combined.lt?.(person1, person2)

          name1 == name2 and age1 > age2 ->
            assert combined.gt?.(person1, person2)

          # Both equal
          name1 == name2 and age1 == age2 ->
            assert compare(person1, person2, combined) == :eq
        end
      end
    end

    property "compose/2 is associative" do
      check all(
              x <- integer(),
              y <- integer()
            ) do
        ord1 = contramap(& &1)
        ord2 = contramap(& &1)
        ord3 = contramap(& &1)

        # (ord1 + ord2) + ord3 == ord1 + (ord2 + ord3)
        left = compose(compose(ord1, ord2), ord3)
        right = compose(ord1, compose(ord2, ord3))

        assert compare(x, y, left) == compare(x, y, right)
      end
    end
  end
end
