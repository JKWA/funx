defmodule Funx.Validator.MapTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Map

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Map

  describe "Map validator" do
    test "passes for maps" do
      assert Map.validate(%{key: "value"}) == %Right{right: %{key: "value"}}
      assert Map.validate(%{}) == %Right{right: %{}}
      assert Map.validate(%{a: 1, b: 2}) == %Right{right: %{a: 1, b: 2}}
    end

    test "fails for non-maps" do
      result = Map.validate(key: "value")
      assert Either.left?(result)

      result = Map.validate("not a map")
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Map.validate([key: "value"], message: fn _ -> "config must be a map" end)

      assert Either.left?(result)
    end
  end

  describe "Map validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Map.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing map" do
      assert Map.validate(%Just{value: %{key: "value"}}, []) == %Right{right: %{key: "value"}}
    end

    test "fails for Just containing non-map" do
      result = Map.validate(%Just{value: [key: "value"]}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Map.validate(%Just{value: "text"},
          message: fn _ -> "config must be a map" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Map.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
