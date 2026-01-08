defmodule Funx.Validator.NotEqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.NotEqual

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.NotEqual

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

  describe "NotEqual validator with basic values" do
    test "passes when values differ" do
      result =
        NotEqual.validate(5,
          value: 3
        )

      assert result == Either.right(5)
    end

    test "fails when values are equal" do
      result =
        NotEqual.validate(5,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "NotEqual validator with custom Eq" do
    test "fails when values are equal under custom Eq" do
      result =
        NotEqual.validate("HELLO",
          value: "hello",
          eq: case_insensitive_eq()
        )

      assert Either.left?(result)
    end

    test "passes when values differ under custom Eq" do
      result =
        NotEqual.validate("HELLO",
          value: "world",
          eq: case_insensitive_eq()
        )

      assert result == Either.right("HELLO")
    end
  end

  describe "NotEqual validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        NotEqual.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value differs" do
      result =
        NotEqual.validate(%Just{value: 5},
          value: 3
        )

      assert result == Either.right(5)
    end

    test "fails for Just when inner value equals reference" do
      result =
        NotEqual.validate(%Just{value: 5},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "NotEqual validator with custom message" do
    test "uses custom message on equality failure" do
      result =
        NotEqual.validate(5,
          value: 5,
          message: fn v -> "#{v} must differ" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["5 must differ"]}} =
               result
    end
  end

  describe "NotEqual validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        NotEqual.validate(5, [])
      end
    end

    test "raises when called with default arity" do
      assert_raise KeyError, fn ->
        NotEqual.validate(5)
      end
    end
  end
end
