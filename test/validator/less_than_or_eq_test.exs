defmodule Funx.Validator.LessThanOrEqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.LessThanOrEqual

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Ord

  alias Funx.Validator.LessThanOrEqual

  defmodule Person do
    @moduledoc false
    require Funx.Macros

    defstruct [:first_name, :last_name, :age]
    Funx.Macros.ord_for(Person, :last_name)

    def age_ord do
      Ord.contramap(& &1.age)
    end
  end

  describe "LessThanOrEqual validator with ordered values" do
    test "passes when value is less than reference" do
      result =
        LessThanOrEqual.validate(3,
          value: 5
        )

      assert result == Either.right(3)
    end

    test "passes when value is equal to reference" do
      result =
        LessThanOrEqual.validate(5,
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails when value is greater than reference" do
      result =
        LessThanOrEqual.validate(7,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with non-numeric ordered values" do
    test "passes for strings ordered lexicographically" do
      result =
        LessThanOrEqual.validate("a",
          value: "b"
        )

      assert result == Either.right("a")
    end

    test "passes for equal strings" do
      result =
        LessThanOrEqual.validate("a",
          value: "a"
        )

      assert result == Either.right("a")
    end

    test "fails for strings ordered lexicographically" do
      result =
        LessThanOrEqual.validate("b",
          value: "a"
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        LessThanOrEqual.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value is less" do
      result =
        LessThanOrEqual.validate(%Just{value: 3},
          value: 5
        )

      assert result == Either.right(3)
    end

    test "passes for Just when inner value is equal" do
      result =
        LessThanOrEqual.validate(%Just{value: 5},
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails for Just when inner value is greater" do
      result =
        LessThanOrEqual.validate(%Just{value: 7},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with custom Ord (Person)" do
    test "uses default Person Ord (by last_name)" do
      alice = %Person{first_name: "Alice", last_name: "Smith", age: 30}
      bob = %Person{first_name: "Bob", last_name: "Brown", age: 25}

      result =
        LessThanOrEqual.validate(bob,
          value: alice
        )

      assert result == Either.right(bob)
    end

    test "passes when Person is equal by default Ord" do
      alice = %Person{first_name: "Alice", last_name: "Smith", age: 30}
      bob = %Person{first_name: "Bob", last_name: "Smith", age: 25}

      result =
        LessThanOrEqual.validate(bob,
          value: alice
        )

      assert result == Either.right(bob)
    end

    test "uses custom Ord via :ord option (age)" do
      younger = %Person{first_name: "Alice", last_name: "Smith", age: 20}
      older = %Person{first_name: "Bob", last_name: "Brown", age: 30}

      result =
        LessThanOrEqual.validate(younger,
          value: older,
          ord: Person.age_ord()
        )

      assert result == Either.right(younger)
    end

    test "fails using custom Ord via :ord option (age)" do
      younger = %Person{first_name: "Alice", last_name: "Smith", age: 20}
      older = %Person{first_name: "Bob", last_name: "Brown", age: 30}

      result =
        LessThanOrEqual.validate(older,
          value: younger,
          ord: Person.age_ord()
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with custom message" do
    test "uses custom message on ordering failure" do
      result =
        LessThanOrEqual.validate(7,
          value: 5,
          message: fn v -> "#{v} is too large" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["7 is too large"]}} =
               result
    end
  end

  describe "LessThanOrEqual validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        LessThanOrEqual.validate(3, [])
      end
    end

    test "raises when called with default arity" do
      assert_raise KeyError, fn ->
        LessThanOrEqual.validate(3)
      end
    end
  end
end
