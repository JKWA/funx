defmodule Funx.Validator.NotInTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.NotIn

  alias Funx.Eq
  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator.NotIn

  defmodule Person do
    @moduledoc false
    require Funx.Macros

    defstruct [:id, :name]

    Funx.Macros.eq_for(Person, :id)

    def id_eq do
      Eq.contramap(& &1.id)
    end
  end

  describe "NotIn validator (membership exclusion)" do
    test "passes when value is not in the disallowed list" do
      assert NotIn.validate("deleted", values: ["active", "inactive"]) ==
               %Right{right: "deleted"}
    end

    test "fails when value is in the disallowed list" do
      result = NotIn.validate("active", values: ["active", "inactive"])
      assert Either.left?(result)
    end

    test "works with atoms" do
      assert NotIn.validate(:pending, values: [:ok, :error]) ==
               %Right{right: :pending}
    end

    test "requires :values option" do
      assert_raise KeyError, fn ->
        NotIn.validate("active", [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        NotIn.validate("active")
      end
    end

    test "supports custom message callback" do
      result =
        NotIn.validate("active",
          values: ["active", "inactive"],
          message: fn _ -> "status is not allowed" end
        )

      assert Either.left?(result)
    end
  end

  describe "NotIn validator with Maybe types" do
    test "passes for Nothing (optional field without value)" do
      assert NotIn.validate(%Nothing{}, values: ["a", "b"]) ==
               %Right{right: %Nothing{}}
    end

    test "passes for Just containing value not in list" do
      assert NotIn.validate(%Just{value: "deleted"}, values: ["active", "inactive"]) ==
               %Right{right: "deleted"}
    end

    test "fails for Just containing value in list" do
      result = NotIn.validate(%Just{value: "active"}, values: ["active", "inactive"])
      assert Either.left?(result)
    end

    test "custom message works with Just values" do
      result =
        NotIn.validate(%Just{value: "active"},
          values: ["active", "inactive"],
          message: fn _ -> "invalid value" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert NotIn.validate(%Nothing{},
               values: ["a", "b"],
               message: fn _ -> "should not see this" end
             ) ==
               %Right{right: %Nothing{}}
    end
  end

  describe "NotIn validator with domain equality (Eq)" do
    test "uses Eq instead of structural equality" do
      alice = %Person{id: 1, name: "Alice"}
      bob = %Person{id: 2, name: "Bob"}
      carol = %Person{id: 3, name: "Carol"}

      assert NotIn.validate(carol,
               values: [alice, bob],
               eq: Person.id_eq()
             ) ==
               %Right{right: carol}
    end

    test "fails when value matches under Eq" do
      alice1 = %Person{id: 1, name: "Alice"}
      alice2 = %Person{id: 1, name: "Alice Clone"}

      result =
        NotIn.validate(alice2,
          values: [alice1],
          eq: Person.id_eq()
        )

      assert Either.left?(result)
    end
  end
end
