defmodule Funx.Validator.RequiredTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Required

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Monad.Maybe.Nothing
  alias Funx.Validator.Required

  describe "Required validator" do
    test "passes for non-nil, non-empty string" do
      assert Required.validate("hello") == %Right{right: "hello"}
    end

    test "passes for non-nil values" do
      assert Required.validate(0) == %Right{right: 0}
      assert Required.validate(false) == %Right{right: false}
      assert Required.validate([]) == %Right{right: []}
    end

    test "fails for nil" do
      result = Required.validate(nil)
      assert Either.left?(result)
    end

    test "fails for empty string" do
      result = Required.validate("")
      assert Either.left?(result)
    end

    test "fails for Nothing (from Prism)" do
      result = Required.validate(%Nothing{})
      assert Either.left?(result)
    end

    test "supports custom error message" do
      result =
        Required.validate(nil, message: fn _ -> "name cannot be blank" end)

      assert Either.left?(result)
    end

    test "supports custom error message for Nothing" do
      result =
        Required.validate(%Nothing{}, message: fn _ -> "field is missing" end)

      assert Either.left?(result)
    end
  end
end
