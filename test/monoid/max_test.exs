defmodule Funx.Monoid.MaxTest do
  use ExUnit.Case, async: true

  import Funx.Monoid.Utils, only: [m_concat: 2]
  import Funx.Ord.Utils

  alias Funx.Monad.Maybe
  alias Funx.Monoid
  alias Funx.Test.Person

  defp ord_ticket, do: Maybe.lift_ord(contramap(& &1.ticket, Funx.Ord))
  defp ord_age, do: Maybe.lift_ord(contramap(& &1.age, Funx.Ord))

  def max_age(people) do
    m_concat(
      %Monoid.Max{
        value: Maybe.nothing(),
        ord: concat([ord_age(), ord_ticket(), Funx.Ord])
      },
      people
    )
  end

  def max_name(people) do
    m_concat(
      %Monoid.Max{
        value: Maybe.nothing(),
        ord: concat([Funx.Ord, ord_age()])
      },
      people
    )
  end

  def max_ticket(people) do
    m_concat(
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
