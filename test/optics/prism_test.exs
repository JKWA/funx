defmodule Funx.Optics.PrismTest do
  use ExUnit.Case, async: true

  doctest Funx.Optics.Prism

  alias Funx.Monad.Maybe
  alias Funx.Optics.Prism
  alias Maybe.{Just, Nothing}

  #
  # Basic preview
  #
  describe "preview/2" do
    test "returns Just for matching value via filter prism" do
      p = Prism.filter(&(&1 > 10))
      assert %Just{value: 12} = 12 |> Prism.preview(p)
    end

    test "returns Nothing for non-matching value via filter prism" do
      p = Prism.filter(&(&1 > 10))
      assert %Nothing{} = 5 |> Prism.preview(p)
    end
  end

  #
  # Basic review
  #
  describe "review/2" do
    test "rebuilds a value using filter prism" do
      p = Prism.filter(&(&1 > 10))
      assert 20 |> Prism.review(p) == 20
    end
  end

  #
  # Prism.some/0
  #
  describe "some/0" do
    test "extracts head from non-empty list" do
      p = Prism.some()
      assert %Just{value: 1} = [1, 2, 3] |> Prism.preview(p)
    end

    test "fails to extract head from empty list or nil" do
      p = Prism.some()
      assert %Nothing{} = [] |> Prism.preview(p)
      assert %Nothing{} = nil |> Prism.preview(p)
    end

    test "review wraps a value in a singleton list" do
      p = Prism.some()
      assert :x |> Prism.review(p) == [:x]
    end
  end

  #
  # Prism.none/0
  #
  describe "none/0" do
    test "preview always returns Nothing" do
      p = Prism.none()
      assert %Nothing{} = 123 |> Prism.preview(p)
      assert %Nothing{} = "hello" |> Prism.preview(p)
      assert %Nothing{} = %{} |> Prism.preview(p)
    end

    test "review always returns nil" do
      p = Prism.none()
      assert :x |> Prism.review(p) == nil
    end
  end

  #
  # Composition
  #
  describe "compose/2" do
    test "composing two filter prisms" do
      p1 = Prism.filter(&(&1 > 0))
      p2 = Prism.filter(&(rem(&1, 2) == 0))
      p = Prism.compose(p1, p2)

      assert %Just{value: 4} = 4 |> Prism.preview(p)
      assert %Nothing{} = -2 |> Prism.preview(p)
      assert %Nothing{} = 3 |> Prism.preview(p)
    end

    test "compose some/0 and filter/1" do
      some = Prism.some()
      even = Prism.filter(&(rem(&1, 2) == 0))
      p = Prism.compose(some, even)

      assert %Just{value: 2} = [2, 3, 4] |> Prism.preview(p)
      assert %Nothing{} = [3, 4] |> Prism.preview(p)
      assert %Nothing{} = [] |> Prism.preview(p)
    end

    test "review rebuilds via both prisms" do
      some = Prism.some()
      inc = Prism.filter(&(&1 > 5))
      p = Prism.compose(some, inc)

      assert 10 |> Prism.review(p) == [10]
    end
  end

  #
  # Key prisms
  #
  describe "key/1 prism" do
    test "extracts value when key exists and value is non-nil" do
      p = Prism.key(:age)

      assert %Just{value: 40} =
               Prism.preview(%{age: 40}, p)
    end

    test "returns Nothing when key exists but value is nil" do
      p = Prism.key(:age)

      assert %Nothing{} =
               Prism.preview(%{age: nil}, p)
    end

    test "returns Nothing when key is missing" do
      p = Prism.key(:age)

      assert %Nothing{} =
               Prism.preview(%{name: "Alice"}, p)
    end

    test "returns Nothing when input is not a map" do
      p = Prism.key(:age)

      assert %Nothing{} =
               Prism.preview(:not_a_map, p)

      assert %Nothing{} =
               Prism.preview(["not", "a", "map"], p)
    end

    test "review builds a map with the key and value" do
      p = Prism.key(:age)

      assert Prism.review(50, p) == %{age: 50}
    end
  end

  #
  # Path prisms
  #
  describe "path/1 prism" do
    test "extracts nested value when full path exists" do
      p = Prism.path([:a, :b, :c])

      assert %Just{value: 10} =
               Prism.preview(%{a: %{b: %{c: 10}}}, p)
    end

    test "returns Nothing when a key is missing" do
      p = Prism.path([:a, :b, :c])

      assert %Nothing{} = Prism.preview(%{a: %{b: %{}}}, p)
      assert %Nothing{} = Prism.preview(%{}, p)
      assert %Nothing{} = Prism.preview(%{a: nil}, p)
    end

    test "treats nil at end of path as Nothing" do
      p = Prism.path([:a, :b])
      assert %Nothing{} = Prism.preview(%{a: %{b: nil}}, p)
    end

    test "fails when intermediate structure is not a map" do
      p = Prism.path([:a, :b])

      assert %Nothing{} = Prism.preview(%{a: 123}, p)
      assert %Nothing{} = Prism.preview(%{a: "string"}, p)
    end

    test "review rebuilds structure from focused value" do
      p = Prism.path([:a, :b, :c])
      assert Prism.review(7, p) == %{a: %{b: %{c: 7}}}
    end

    test "path prism composes with another prism" do
      outer = Prism.path([:a, :b])
      inner = Prism.filter(&(rem(&1, 2) == 0))
      p = Prism.compose(outer, inner)

      assert %Just{value: 4} = Prism.preview(%{a: %{b: 4}}, p)
      assert %Nothing{} = Prism.preview(%{a: %{b: 3}}, p)
      assert %Nothing{} = Prism.preview(%{a: %{b: nil}}, p)
    end

    #
    # Empty path tests: ensure coverage of safe_get_path([], …) and safe_put_path([], …)
    #
    test "review with empty path replaces the entire structure" do
      p = Prism.path([])

      assert Prism.review(123, p) == 123
      assert Prism.review(%{x: 1}, p) == %{x: 1}
      assert Prism.review("new", p) == "new"
    end

    test "preview with empty path always returns Nothing" do
      p = Prism.path([])

      assert %Nothing{} = Prism.preview(%{a: 1}, p)
      assert %Nothing{} = Prism.preview(:anything, p)
    end
  end
end
