defmodule Monex.Monoid.MaxTest do
  use ExUnit.Case, async: true
  import Monex.Ord.Utils
  alias Monex.Maybe
  alias Monex.Monoid
  alias Monex.Test.Person

  defp ord_ticket, do: Maybe.get_ord(contramap(& &1.ticket, Monex.Ord))
  defp ord_age, do: Maybe.get_ord(contramap(& &1.age, Monex.Ord))

  def max_age(people) do
    Monoid.Utils.concat(
      %Monoid.Max{
        value: Maybe.nothing(),
        ord: concat([ord_age(), ord_ticket(), Monex.Ord])
      },
      people
    )
  end

  def max_name(people) do
    Monoid.Utils.concat(
      %Monoid.Max{
        value: Maybe.nothing(),
        ord: concat([Monex.Ord, ord_age()])
      },
      people
    )
  end

  def max_ticket(people) do
    Monoid.Utils.concat(
      %Monoid.Max{
        value: Maybe.nothing(),
        ord: concat([ord_ticket(), ord_age()])
      },
      people
    )
  end

  describe "Max Monoid" do
    test "with ordered persons" do
      alice_vip = Maybe.pure(%Person{name: "Alice", age: 30, ticket: :vip})
      alice_basic = Maybe.pure(%Person{name: "Alice", age: 30, ticket: :basic})
      bob = Maybe.pure(%Person{name: "Bob", age: 25, ticket: :basic})

      assert max_age([alice_vip, bob]) == alice_vip

      assert max_name([bob, alice_vip]) == bob

      assert max_name([]) == Maybe.nothing()

      assert max_ticket([alice_vip, alice_basic]) == alice_vip
      assert max_ticket([bob, alice_basic]) == alice_basic
      assert max_ticket([alice_basic, bob]) == alice_basic
    end
  end
end
