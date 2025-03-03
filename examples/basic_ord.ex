defmodule Basic.Ord do
  import Kernel, except: [min: 2, max: 2]
  import Funx.Ord.Utils

  def get_max_fruit(fruit_1, fruit_2) do
    max(fruit_1, fruit_2)
  end

  defmodule LengthOrd do
    def lt?(a, b), do: String.length(a) < String.length(b)
    def le?(a, b), do: String.length(a) <= String.length(b)
    def gt?(a, b), do: String.length(a) > String.length(b)
    def ge?(a, b), do: String.length(a) >= String.length(b)
  end

  def max_fruit_length_base(fruit_1, fruit_2) do
    max(fruit_1, fruit_2, LengthOrd)
  end

  def length_ord(), do: contramap(&String.length/1)

  def max_fruit_length(fruit_1, fruit_2) do
    max(fruit_1, fruit_2, length_ord())
  end

  def min_fruit_length(fruit_1, fruit_2) do
    min(fruit_1, fruit_2, length_ord())
  end

  def compare_fruit_length(fruit_1, fruit_2) do
    compare(fruit_1, fruit_2, length_ord())
  end

  def fruit_key_ord, do: contramap(&Map.get(&1, :fruit))

  def max_by_fruit_key(map1, map2) do
    max(map1, map2, fruit_key_ord())
  end

  def fruit_key_length_ord_1(), do: contramap(&String.length(Map.get(&1, :fruit)))

  def max_length_by_fruit_key_1(map1, map2) do
    max(map1, map2, fruit_key_length_ord_1())
  end

  def fruit_key_length_ord_2(), do: contramap(&Map.get(&1, :fruit), LengthOrd)

  def max_length_by_fruit_key_2(map1, map2) do
    max(map1, map2, fruit_key_length_ord_2())
  end

  def sort_by_fruit_key do
    fruit_key_ord() |> comparator()
  end

  def sort_by_fruit_key_length do
    fruit_key_length_ord_2() |> comparator()
  end

  def demo_sort_fruits do
    fruits = [%{fruit: "banana"}, %{fruit: "kiwi"}, %{fruit: "apple"}, %{fruit: "watermelon"}]

    sorted_alphabetically = Enum.sort(fruits, sort_by_fruit_key())
    sorted_by_length = Enum.sort(fruits, sort_by_fruit_key_length())

    %{
      sorted_alphabetically: sorted_alphabetically,
      sorted_by_length: sorted_by_length
    }
  end

  def sort_by_fruit_key_desc do
    fruit_key_ord() |> reverse() |> comparator()
  end

  def demo_sort_fruits_reverse do
    fruits = [%{fruit: "banana"}, %{fruit: "kiwi"}, %{fruit: "apple"}, %{fruit: "watermelon"}]

    reverse_sorted = Enum.sort(fruits, sort_by_fruit_key_desc())

    %{
      reverse_sorted: reverse_sorted
    }
  end
end
