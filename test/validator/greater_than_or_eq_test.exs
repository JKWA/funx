defmodule Funx.Validator.GreaterThanOrEqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.GreaterThanOrEqual

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Ord

  alias Funx.Validator.GreaterThanOrEqual

  defmodule Person do
    @moduledoc false
    require Funx.Macros

    defstruct [:first_name, :last_name, :age]
    Funx.Macros.ord_for(Person, :last_name)

    def age_ord do
      Ord.contramap(& &1.age)
    end
  end

  describe "GreaterThanOrEqual validator with ordered values" do
    test "passes when value is greater than reference" do
      result =
        GreaterThanOrEqual.validate(7,
          value: 5
        )

      assert result == Either.right(7)
    end

    test "passes when value is equal to reference" do
      result =
        GreaterThanOrEqual.validate(5,
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails when value is less than reference" do
      result =
        GreaterThanOrEqual.validate(3,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThanOrEqual validator with non-numeric ordered values" do
    test "passes for strings ordered lexicographically" do
      result =
        GreaterThanOrEqual.validate("b",
          value: "a"
        )

      assert result == Either.right("b")
    end

    test "fails for strings ordered lexicographically" do
      result =
        GreaterThanOrEqual.validate("a",
          value: "b"
        )

      assert Either.left?(result)
    end

    test "passes for equal strings" do
      result =
        GreaterThanOrEqual.validate("a",
          value: "a"
        )

      assert result == Either.right("a")
    end
  end

  describe "GreaterThanOrEqual validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        GreaterThanOrEqual.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value is greater" do
      result =
        GreaterThanOrEqual.validate(%Just{value: 7},
          value: 5
        )

      assert result == Either.right(7)
    end

    test "passes for Just when inner value is equal" do
      result =
        GreaterThanOrEqual.validate(%Just{value: 5},
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails for Just when inner value is less" do
      result =
        GreaterThanOrEqual.validate(%Just{value: 3},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThanOrEqual validator with custom Ord (Person)" do
    test "uses default Person Ord (by last_name)" do
      alice = %Person{first_name: "Alice", last_name: "Smith", age: 30}
      bob = %Person{first_name: "Bob", last_name: "Taylor", age: 25}

      result =
        GreaterThanOrEqual.validate(bob,
          value: alice
        )

      assert result == Either.right(bob)
    end

    test "fails when Person is less by default Ord" do
      alice = %Person{first_name: "Alice", last_name: "Smith", age: 30}
      bob = %Person{first_name: "Bob", last_name: "Brown", age: 25}

      result =
        GreaterThanOrEqual.validate(bob,
          value: alice
        )

      assert Either.left?(result)
    end

    test "uses custom Ord via :ord option (age)" do
      younger = %Person{first_name: "Alice", last_name: "Smith", age: 20}
      older = %Person{first_name: "Bob", last_name: "Brown", age: 30}

      result =
        GreaterThanOrEqual.validate(older,
          value: younger,
          ord: Person.age_ord()
        )

      assert result == Either.right(older)
    end

    test "fails using custom Ord via :ord option (age)" do
      younger = %Person{first_name: "Alice", last_name: "Smith", age: 20}
      older = %Person{first_name: "Bob", last_name: "Brown", age: 30}

      result =
        GreaterThanOrEqual.validate(younger,
          value: older,
          ord: Person.age_ord()
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThanOrEqual validator with custom message" do
    test "uses custom message on ordering failure" do
      result =
        GreaterThanOrEqual.validate(3,
          value: 5,
          message: fn v -> "#{v} is too small" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["3 is too small"]}} =
               result
    end
  end

  describe "GreaterThanOrEqual validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        GreaterThanOrEqual.validate(7, [])
      end
    end

    test "raises when called with default arity" do
      assert_raise KeyError, fn ->
        GreaterThanOrEqual.validate(7)
      end
    end
  end
end
