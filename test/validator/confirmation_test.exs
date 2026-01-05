defmodule Funx.Validator.ConfirmationTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Confirmation

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Confirmation

  describe "Confirmation validator" do
    test "passes when value matches confirmation field" do
      data = %{password: "secret123", password_confirmation: "secret123"}

      assert Confirmation.validate("secret123", field: :password_confirmation, data: data) ==
               %Right{right: "secret123"}
    end

    test "fails when value doesn't match confirmation" do
      data = %{password: "secret123", password_confirmation: "different"}

      result =
        Confirmation.validate("secret123", field: :password_confirmation, data: data)

      assert Either.left?(result)
    end

    test "requires :field option" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret", data: %{})
      end
    end

    test "requires :data option" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret", field: :password_confirmation)
      end
    end

    test "raises when called with single argument (default opts)" do
      assert_raise KeyError, fn ->
        Confirmation.validate("secret")
      end
    end

    test "supports custom message callback" do
      data = %{password: "secret123", password_confirmation: "different"}

      result =
        Confirmation.validate("secret123",
          field: :password_confirmation,
          data: data,
          message: fn _ -> "passwords do not match" end
        )

      assert Either.left?(result)
    end
  end

  describe "Confirmation validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      data = %{password: "secret"}

      assert Confirmation.validate(%Nothing{}, field: :password, data: data) ==
               %Right{right: %Nothing{}}
    end

    test "passes for Just containing matching value" do
      data = %{password: "secret123", password_confirmation: "secret123"}

      assert Confirmation.validate(%Just{value: "secret123"},
               field: :password_confirmation,
               data: data
             ) == %Right{right: "secret123"}
    end

    test "fails for Just containing non-matching value" do
      data = %{password: "secret123", password_confirmation: "different"}

      result =
        Confirmation.validate(%Just{value: "different"}, field: :password, data: data)

      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      data = %{password: "secret123", password_confirmation: "different"}

      result =
        Confirmation.validate(%Just{value: "different"},
          field: :password,
          data: data,
          message: fn _ -> "passwords do not match" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      data = %{password: "secret"}

      assert Confirmation.validate(%Nothing{},
               field: :password,
               data: data,
               message: fn _ -> "should not see this" end
             ) == %Right{right: %Nothing{}}
    end
  end
end
