defmodule Funx.Ord.UtilsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Kernel, except: [min: 2, max: 2]
  import Funx.Ord.Utils

  alias Funx.Monad.{Either, Identity, Maybe}
  alias Funx.Ord.Any
  alias Funx.Test.Person
  doctest Funx.Ord.Utils

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

  describe "reverse/1" do
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

  describe "reverse/1 map" do
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

  describe "contramap/2 with string length comparison" do
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

  describe "composed contramap/2" do
    test "compares tuples by name length using two composed contramaps" do
      tuple_name_length = contramap(&(&1 |> elem(0) |> String.length()))

      assert compare({"banana", 6}, {"apple", 5}, tuple_name_length) == :gt
      assert compare({"pear", 4}, {"peach", 5}, tuple_name_length) == :lt
      assert compare({"grape", 5}, {"peach", 5}, tuple_name_length) == :eq
    end
  end

  describe "composed contramap/2 map" do
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

  defp ord_name, do: contramap(& &1.name)
  defp ord_age, do: contramap(& &1.age)
  defp ord_ticket, do: contramap(& &1.ticket)
  defp ord_append, do: append(ord_name(), ord_age())
  defp ord_concat, do: concat([ord_name(), ord_age()])
  defp ord_concat_age, do: concat([ord_age(), ord_ticket(), Funx.Ord])
  defp ord_concat_default, do: concat([Funx.Ord])

  defp ord_empty, do: concat([])

  describe "Ord Monoid" do
    test "with ordered persons" do
      alice = %Person{name: "Alice", age: 30, ticket: :b}
      bob = %Person{name: "Bob", age: 25, ticket: :a}
      bob_b = %Person{name: "Bob", age: 30, ticket: :a}
      bob_c = %Person{name: "Bob", age: 30, ticket: :b}

      assert compare(alice, bob, ord_name()) == :lt
      assert compare(bob, alice, ord_name()) == :gt
      assert compare(alice, alice, ord_name()) == :eq

      assert compare(alice, bob, ord_age()) == :gt
      assert compare(bob, alice, ord_age()) == :lt
      assert compare(alice, alice, ord_age()) == :eq

      assert compare(alice, bob, ord_ticket()) == :gt
      assert compare(bob, alice, ord_ticket()) == :lt
      assert compare(alice, alice, ord_ticket()) == :eq

      assert compare(alice, bob, ord_append()) == :lt
      assert compare(bob, alice, ord_append()) == :gt
      assert compare(alice, alice, ord_append()) == :eq

      assert compare(alice, bob, ord_concat()) == :lt
      assert compare(bob, alice, ord_concat()) == :gt
      assert compare(alice, alice, ord_concat()) == :eq

      assert compare(alice, bob, ord_concat_age()) == :gt
      assert compare(bob, alice, ord_concat_age()) == :lt
      assert compare(alice, alice, ord_concat_age()) == :eq
      assert compare(alice, bob_b, ord_concat_age()) == :gt
      assert compare(alice, bob_c, ord_concat_age()) == :lt

      assert compare(alice, bob, ord_empty()) == :eq
      assert compare(bob, alice, ord_empty()) == :eq
      assert compare(alice, alice, ord_empty()) == :eq

      assert ord_concat().lt?.(alice, bob)
      assert ord_concat().le?.(alice, alice)
      assert ord_concat().gt?.(bob, alice)
      assert ord_concat().ge?.(bob, alice)
    end

    test "with default ord persons (name)" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      assert compare(alice, bob, ord_concat_default()) == :lt
      assert compare(bob, alice, ord_concat_default()) == :gt
      assert compare(alice, alice, ord_concat_default()) == :eq
    end
  end
end
