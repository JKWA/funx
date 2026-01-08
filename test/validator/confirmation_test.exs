defmodule Funx.Validator.ConfirmationTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Confirmation

  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Validator.Confirmation

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

  describe "Confirmation validator with matching values" do
    test "passes when value matches referenced field" do
      data = %{password: "secret", password_confirmation: "secret"}

      assert Confirmation.validate(
               "secret",
               field: :password,
               data: data
             ) == Either.right("secret")
    end

    test "passes for identical non-string values" do
      data = %{count: 5, count_confirmation: 5}

      assert Confirmation.validate(
               5,
               field: :count,
               data: data
             ) == Either.right(5)
    end
  end

  describe "Confirmation validator with non-matching values" do
    test "fails when value does not match referenced field" do
      data = %{password: "secret", password_confirmation: "wrong"}

      result =
        Confirmation.validate(
          "wrong",
          field: :password,
          data: data
        )

      assert Either.left?(result)
    end
  end

  describe "Confirmation validator with custom Eq" do
    test "passes using case-insensitive equality" do
      data = %{password: "hello", password_confirmation: "HELLO"}

      assert Confirmation.validate(
               "HELLO",
               field: :password,
               data: data,
               eq: case_insensitive_eq()
             ) == Either.right("HELLO")
    end

    test "fails when values differ under custom Eq" do
      data = %{password: "hello", password_confirmation: "world"}

      result =
        Confirmation.validate(
          "world",
          field: :password,
          data: data,
          eq: case_insensitive_eq()
        )

      assert Either.left?(result)
    end
  end

  describe "Confirmation validator with custom message" do
    test "uses custom message on failure" do
      data = %{password: "secret", password_confirmation: "wrong"}

      result =
        Confirmation.validate(
          "wrong",
          field: :password,
          data: data,
          message: fn _ -> "does not match password" end
        )

      assert %Either.Left{left: %{errors: ["does not match password"]}} = result
    end
  end

  describe "Confirmation validator with Maybe values" do
    test "passes for Nothing" do
      data = %{password: "secret"}

      assert Confirmation.validate(
               %Nothing{},
               field: :password,
               data: data
             ) == Either.right(%Nothing{})
    end

    test "passes for Just when values match" do
      data = %{password: 5}

      assert Confirmation.validate(
               %Just{value: 5},
               field: :password,
               data: data
             ) == Either.right(5)
    end

    test "fails for Just when values differ" do
      data = %{password: 5}

      result =
        Confirmation.validate(
          %Just{value: 6},
          field: :password,
          data: data
        )

      assert Either.left?(result)
    end

    test "works with custom Eq on Just values" do
      data = %{password: "hello"}

      assert Confirmation.validate(
               %Just{value: "HELLO"},
               field: :password,
               data: data,
               eq: case_insensitive_eq()
             ) == Either.right("HELLO")
    end
  end

  describe "Confirmation validator argument validation" do
    test "raises when :field option is missing" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret", data: %{})
      end
    end

    test "raises when :data option is missing" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret", field: :password)
      end
    end

    test "raises when called with default arity" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret")
      end
    end
  end
end
