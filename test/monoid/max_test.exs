defmodule Monex.Monoid.MaxTest do
  use ExUnit.Case, async: true
  import Monex.Ord.Utils
  alias Monex.Monoid
  alias Monex.Test.Person

  defp ord_name, do: contramap(& &1.name)
  defp ord_age, do: contramap(& &1.age)

  def max_age(people) do
    Monoid.Utils.concat(
      %Monoid.Max{
        value: %Person{age: Float.min_finite(), name: nil},
        ord: concat([ord_age(), ord_name()])
      },
      people
    )
  end

  def max_name(people) do
    Monoid.Utils.concat(
      %Monoid.Max{
        value: %Person{age: Float.min_finite(), name: nil},
        ord: concat([ord_name(), ord_age()])
      },
      people
    )
  end

  describe "Max Monoid" do
    test "with ordered persons" do
      alice = %Person{name: "Alice", age: 30}
      bob = %Person{name: "Bob", age: 25}

      assert max_age([alice, bob]) == alice

      assert max_name([bob, alice]) == bob
    end
  end
end
