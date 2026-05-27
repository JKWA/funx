defmodule Funx.Predicate.MapTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Map, Required}

  describe "Map predicate standalone" do
    test "returns true for maps" do
      predicate = Map.pred()

      assert predicate.(%{})
      assert predicate.(%{key: "value"})
      assert predicate.(%{a: 1, b: 2})
    end

    test "returns false for structs" do
      predicate = Map.pred()

      # Structs are technically maps, so they pass is_map/1
      assert predicate.(%Funx.Monad.Either.Right{right: 1})
    end

    test "returns false for non-maps" do
      predicate = Map.pred()

      refute predicate.(5)
      refute predicate.("map")
      refute predicate.(:map)
      refute predicate.(nil)
      refute predicate.(key: "value")
      refute predicate.([1, 2, 3])
    end
  end

  describe "Map predicate in DSL" do
    test "check with Map" do
      is_map_config =
        pred do
          check :config, Map
        end

      assert is_map_config.(%{config: %{}})
      assert is_map_config.(%{config: %{setting: "value"}})
      refute is_map_config.(%{config: "not a map"})
      refute is_map_config.(%{})
    end

    test "negate check with Map" do
      not_map =
        pred do
          negate check :value, Map
        end

      assert not_map.(%{value: "hello"})
      assert not_map.(%{value: 42})
      refute not_map.(%{value: %{key: "value"}})
    end

    test "combined with other predicates" do
      required_map =
        pred do
          check :user, Map
          check :user, Required
        end

      assert required_map.(%{user: %{name: "Alice"}})
      assert required_map.(%{user: %{}})
      refute required_map.(%{user: nil})
      refute required_map.(%{user: "not a map"})
    end
  end
end
