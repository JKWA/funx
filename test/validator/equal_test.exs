defmodule Funx.Validator.EqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Equal

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.Equal

  defp case_insensitive_eq do
    %{
      eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) == String.downcase(b)
      end,
      not_eq?: fn a, b when is_binary(a) and is_binary(b) ->
        String.downcase(a) != String.downcase(b)
      end
    }
  end

  describe "Equal validator with matching values" do
    test "passes for identical integers" do
      assert Equal.validate(5, value: 5) == Either.right(5)
    end

    test "passes for identical strings" do
      assert Equal.validate("hello", value: "hello") == Either.right("hello")
    end

    test "passes for identical atoms" do
      assert Equal.validate(:ok, value: :ok) == Either.right(:ok)
    end

    test "passes for identical maps" do
      map = %{a: 1, b: 2}
      assert Equal.validate(map, value: map) == Either.right(map)
    end

    test "passes for identical tuples" do
      tuple = {:ok, "value"}
      assert Equal.validate(tuple, value: tuple) == Either.right(tuple)
    end

    test "passes for identical nested lists" do
      list = [1, [2, 3]]
      assert Equal.validate(list, value: list) == Either.right(list)
    end
  end

  describe "Equal validator with non-matching values" do
    test "fails for different integers" do
      result = Equal.validate(5, value: 6)
      assert Either.left?(result)
    end

    test "fails for different strings" do
      result = Equal.validate("hello", value: "world")
      assert Either.left?(result)
    end

    test "fails for different maps" do
      result = Equal.validate(%{a: 1}, value: %{a: 2})
      assert Either.left?(result)
    end

    test "fails for mixed types" do
      result = Equal.validate(1, value: "1")
      assert Either.left?(result)
    end
  end

  describe "Equal validator with custom Eq" do
    test "passes using case-insensitive equality" do
      assert Equal.validate("HELLO",
               value: "hello",
               eq: case_insensitive_eq()
             ) == Either.right("HELLO")
    end

    test "fails when values differ under custom Eq" do
      result =
        Equal.validate("HELLO",
          value: "world",
          eq: case_insensitive_eq()
        )

      assert Either.left?(result)
    end

    test "uses default Eq when no custom Eq provided" do
      result = Equal.validate("HELLO", value: "hello")
      assert Either.left?(result)
    end
  end

  describe "Equal validator with custom message" do
    test "uses custom message on failure" do
      result =
        Equal.validate(5,
          value: 6,
          message: fn v -> "#{v} is not equal" end
        )

      assert %Either.Left{left: %{errors: ["5 is not equal"]}} = result
    end

    test "custom message receives actual value" do
      result =
        Equal.validate("foo",
          value: "bar",
          message: fn v -> "got #{v}" end
        )

      assert %Either.Left{left: %{errors: ["got foo"]}} = result
    end
  end

  describe "Equal validator with Maybe values" do
    test "passes for Nothing (optional field without value)" do
      assert Equal.validate(%Nothing{}, value: 5) == Either.right(%Nothing{})
    end

    test "passes for Just when values match" do
      assert Equal.validate(%Just{value: 5}, value: 5) == Either.right(5)
    end

    test "fails for Just when values differ" do
      result = Equal.validate(%Just{value: 5}, value: 6)
      assert Either.left?(result)
    end

    test "works with custom Eq on Just values" do
      assert Equal.validate(%Just{value: "HELLO"},
               value: "hello",
               eq: case_insensitive_eq()
             ) == Either.right("HELLO")
    end

    test "custom message works with Just values" do
      result =
        Equal.validate(%Just{value: 1},
          value: 2,
          message: fn _ -> "values must match" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom Eq" do
      assert Equal.validate(%Nothing{},
               value: "anything",
               eq: case_insensitive_eq()
             ) == Either.right(%Nothing{})
    end

    test "Nothing passes regardless of custom message" do
      assert Equal.validate(%Nothing{},
               value: 5,
               message: fn _ -> "should not see this" end
             ) == Either.right(%Nothing{})
    end
  end

  describe "Equal validator with struct module equality" do
    defmodule Purchase do
      defstruct [:id]
    end

    defmodule Refund do
      defstruct [:id]
    end

    defmodule Charge do
      defstruct [:id]
    end

    test "passes when value is a struct and expected value is its module" do
      assert Equal.validate(%Purchase{id: 1}, value: Purchase) ==
               Either.right(%Purchase{id: 1})

      assert Equal.validate(%Refund{id: 2}, value: Refund) ==
               Either.right(%Refund{id: 2})
    end

    test "fails when value is a struct but module does not match" do
      result = Equal.validate(%Charge{id: 3}, value: Purchase)
      assert Either.left?(result)
    end

    test "fails when expected value is a module but value is not a struct" do
      result = Equal.validate("purchase", value: Purchase)
      assert Either.left?(result)
    end

    test "works with Just wrapping a struct" do
      assert Equal.validate(%Just{value: %Purchase{id: 1}}, value: Purchase) ==
               Either.right(%Purchase{id: 1})

      result =
        Equal.validate(%Just{value: %Charge{id: 2}}, value: Purchase)

      assert Either.left?(result)
    end

    test "Nothing still passes through when expected value is a module" do
      assert Equal.validate(%Nothing{}, value: Purchase) ==
               Either.right(%Nothing{})
    end

    test "custom message is applied for struct equality failures" do
      result =
        Equal.validate(%Charge{id: 1},
          value: Purchase,
          message: fn _ -> "wrong type" end
        )

      assert %Either.Left{left: %{errors: ["wrong type"]}} = result
    end
  end

  describe "Equal validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        Equal.validate(5, [])
      end
    end

    test "raises when called with default arity" do
      assert_raise KeyError, fn ->
        Equal.validate(5)
      end
    end
  end
end
