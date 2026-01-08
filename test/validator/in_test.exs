defmodule Funx.Validator.InTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.In

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator.In

  describe "In validator (membership)" do
    test "passes when value is in the allowed list" do
      assert In.validate("active", values: ["active", "inactive", "pending"]) ==
               %Right{right: "active"}
    end

    test "fails when value is not in the allowed list" do
      result = In.validate("deleted", values: ["active", "inactive", "pending"])
      assert Either.left?(result)
    end

    test "works with atoms" do
      assert In.validate(:ok, values: [:ok, :error]) == %Right{right: :ok}
    end

    test "requires :values option" do
      assert_raise KeyError, fn ->
        In.validate("active", [])
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        In.validate("active")
      end
    end

    test "supports custom message callback" do
      result =
        In.validate("deleted",
          values: ["active", "inactive"],
          message: fn _ -> "invalid status" end
        )

      assert %Either.Left{} = result
    end
  end

  describe "In validator with Maybe types" do
    test "passes for Nothing (optional field without value)" do
      assert In.validate(%Nothing{}, values: ["a", "b", "c"]) ==
               %Right{right: %Nothing{}}
    end

    test "passes for Just containing value in list" do
      assert In.validate(%Just{value: "active"}, values: ["active", "inactive"]) ==
               %Right{right: "active"}
    end

    test "fails for Just containing value not in list" do
      result = In.validate(%Just{value: "deleted"}, values: ["active", "inactive"])
      assert Either.left?(result)
    end

    test "custom message is applied for Just failures" do
      result =
        In.validate(%Just{value: "deleted"},
          values: ["active", "inactive"],
          message: fn _ -> "invalid status" end
        )

      assert %Either.Left{} = result
    end

    test "Nothing passes regardless of custom message" do
      assert In.validate(%Nothing{},
               values: ["a", "b"],
               message: fn _ -> "should not see this" end
             ) ==
               %Right{right: %Nothing{}}
    end
  end

  describe "In validator with custom Eq" do
    test "uses Eq for case-insensitive string membership" do
      case_insensitive = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      assert In.validate("RED",
               values: ["red", "green", "blue"],
               eq: case_insensitive
             ) == %Right{right: "RED"}
    end

    test "fails when Eq does not match any value" do
      case_insensitive = %{
        eq?: fn a, b -> String.downcase(a) == String.downcase(b) end,
        not_eq?: fn a, b -> String.downcase(a) != String.downcase(b) end
      }

      result =
        In.validate("yellow",
          values: ["red", "green", "blue"],
          eq: case_insensitive
        )

      assert Either.left?(result)
    end
  end

  describe "In validator with domain equality" do
    defmodule Person do
      defstruct [:id]
    end

    test "uses Eq instead of structural equality" do
      eq_by_id = %{
        eq?: fn a, b -> a.id == b.id end,
        not_eq?: fn a, b -> a.id != b.id end
      }

      alice = %Person{id: 1}
      bob = %Person{id: 1}
      carol = %Person{id: 2}

      assert In.validate(bob,
               values: [alice],
               eq: eq_by_id
             ) == %Right{right: bob}

      result =
        In.validate(carol,
          values: [alice],
          eq: eq_by_id
        )

      assert Either.left?(result)
    end
  end
end
