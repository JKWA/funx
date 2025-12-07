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

  defmodule Profile do
    defstruct [:age, :score]
  end

  defmodule User do
    defstruct [:name, :profile]
  end

  describe "path/1 prism with structs (preview)" do
    test "preview reads an existing struct field" do
      u = %User{name: "A", profile: %Profile{age: 30}}
      p = Prism.path([:profile, :age])

      assert %Maybe.Just{value: 30} = Prism.preview(u, p)
    end

    test "preview returns Nothing when key is missing in a struct" do
      u = %User{name: "A", profile: %Profile{}}
      p = Prism.path([:profile, :age])

      assert %Maybe.Nothing{} = Prism.preview(u, p)
    end

    test "preview returns Nothing when struct is encountered where map was expected" do
      u = %User{name: "A", profile: %Profile{age: %Profile{}}}
      # score doesn't exist inside nested struct
      p = Prism.path([:profile, :age, :score])

      assert %Maybe.Nothing{} = Prism.preview(u, p)
    end
  end

  describe "path/1 prism with structs (review)" do
    test "review constructs fresh nested struct (lawful prism behavior)" do
      p = Prism.path([:profile, :age], structs: [User, Profile])

      # Prisms rebuild from scratch - they do not merge or preserve other fields
      # This is lawful prism behavior: review : a -> s has no access to original s
      assert Prism.review(30, p) ==
               %User{name: nil, profile: %Profile{age: 30, score: nil}}
    end

    test "review creates minimal structure for plain maps" do
      p = Prism.path([:profile, :age])

      # Without :structs option, creates plain maps with only the specified path
      assert Prism.review(40, p) == %{profile: %{age: 40}}
    end

    test "review falls back to maps when struct path is invalid" do
      u = %User{name: "A", profile: %Profile{age: 20}}

      # :foo is NOT valid for struct User
      # User.name is not a nested struct, so [:name, :foo] is invalid
      p = Prism.path([:name, :foo], structs: [User])

      # Should fall back to Nothing on preview
      assert %Maybe.Nothing{} = Prism.preview(u, p)

      # On review, falls back to creating plain maps instead of raising
      assert Prism.review("value", p) == %{name: %{foo: "value"}}
    end

    test "review constructs deeply nested structs from focused value" do
      p = Prism.path([:profile, :score], structs: [User, Profile])

      # Constructs fresh nested structs - other fields are nil
      result = Prism.review(10, p)

      assert match?(%{profile: %{score: 10}}, result)
      assert is_struct(result.profile, Profile)
      assert result == %User{name: nil, profile: %Profile{age: nil, score: 10}}
    end

    test "review with empty path and structs returns the value directly" do
      p = Prism.path([], structs: [User])
      assert Prism.review(42, p) == 42
    end

    test "review with single key and no struct modules creates a plain map" do
      p = Prism.path([:foo])
      assert Prism.review("bar", p) == %{foo: "bar"}
    end

    test "review with multiple keys and no struct modules creates nested maps" do
      p = Prism.path([:a, :b, :c])
      assert Prism.review("value", p) == %{a: %{b: %{c: "value"}}}
    end

    test "review falls back to maps when struct has missing intermediate field" do
      # Profile doesn't have a :details field
      p = Prism.path([:profile, :details, :age], structs: [User, Profile])
      result = Prism.review(30, p)

      # Should fall back to creating plain maps
      assert result == %{profile: %{details: %{age: 30}}}
    end

    test "review uses map-building bind when structs are exhausted before path is complete" do
      p =
        Prism.path(
          [:a, :b, :c],
          # only one struct, but three keys
          structs: [User]
        )

      result = Prism.review(42, p)

      assert result == %{a: %{b: %{c: 42}}}
    end

    test "path handles struct with nil nested value" do
      u = %User{name: "Charlie", profile: nil}
      p = Prism.path([:profile, :age])

      # Should return Nothing when intermediate value is nil
      assert %Maybe.Nothing{} = Prism.preview(u, p)
    end
  end

  describe "path/1 edge cases" do
    test "path with single-element list and struct" do
      p = Prism.path([:name], structs: [User])
      result = Prism.review("David", p)
      assert result == %User{name: "David", profile: nil}
    end

    test "path with mismatched struct count (more keys than structs)" do
      # When we have more path keys than struct modules,
      # it should use structs for what it can and fall back to maps
      p = Prism.path([:profile, :age, :extra], structs: [User])
      result = Prism.review("value", p)

      # Should fall back to maps because User.profile isn't defined in struct list
      assert result == %{profile: %{age: %{extra: "value"}}}
    end

    test "path with struct but trying to access non-existent field" do
      # This tests the error case in build_struct_path_maybe for missing key
      p = Prism.path([:nonexistent], structs: [User])
      result = Prism.review("test", p)

      # Should fall back to plain map since field doesn't exist
      assert result == %{nonexistent: "test"}
    end
  end

  describe "Monoid structure via PrismCompose" do
    alias Funx.Monoid.PrismCompose

    test "prisms form a monoid under composition via PrismCompose" do
      import Funx.Monoid

      p1 = PrismCompose.new(Prism.filter(&(&1 > 0)))
      p2 = PrismCompose.new(Prism.filter(&(rem(&1, 2) == 0)))

      # Composition via Monoid.append
      composed = append(p1, p2) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: 4} = Prism.preview(4, composed)
      assert %Maybe.Nothing{} = Prism.preview(3, composed)
      assert %Maybe.Nothing{} = Prism.preview(-2, composed)
    end

    test "identity prism preserves values" do
      import Funx.Monoid

      id = empty(%PrismCompose{})
      p = PrismCompose.new(Prism.filter(&(&1 > 10)))

      # Left identity: append(id, p) == p
      left = append(id, p) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: 15} = Prism.preview(15, left)
      assert %Maybe.Nothing{} = Prism.preview(5, left)

      # Right identity: append(p, id) == p
      right = append(p, id) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: 15} = Prism.preview(15, right)
      assert %Maybe.Nothing{} = Prism.preview(5, right)
    end

    test "composition is associative" do
      import Funx.Monoid

      p1 = PrismCompose.new(Prism.filter(&(&1 > 0)))
      p2 = PrismCompose.new(Prism.filter(&(rem(&1, 2) == 0)))
      p3 = PrismCompose.new(Prism.filter(&(&1 < 100)))

      # (p1 . p2) . p3 == p1 . (p2 . p3)
      left_assoc = append(append(p1, p2), p3) |> PrismCompose.unwrap()
      right_assoc = append(p1, append(p2, p3)) |> PrismCompose.unwrap()

      # Test with a value that should match all filters
      assert %Maybe.Just{value: 4} = Prism.preview(4, left_assoc)
      assert %Maybe.Just{value: 4} = Prism.preview(4, right_assoc)

      # Test with a value that should fail first filter
      assert %Maybe.Nothing{} = Prism.preview(-2, left_assoc)
      assert %Maybe.Nothing{} = Prism.preview(-2, right_assoc)

      # Test with a value that should fail second filter
      assert %Maybe.Nothing{} = Prism.preview(3, left_assoc)
      assert %Maybe.Nothing{} = Prism.preview(3, right_assoc)

      # Test with a value that should fail third filter
      assert %Maybe.Nothing{} = Prism.preview(200, left_assoc)
      assert %Maybe.Nothing{} = Prism.preview(200, right_assoc)
    end

    test "none is a zero/annihilator for composition" do
      p = Prism.filter(&(&1 > 10))
      zero = Prism.none()

      # Composing with none annihilates
      left_zero = Prism.compose(zero, p)
      right_zero = Prism.compose(p, zero)

      assert %Maybe.Nothing{} = Prism.preview(15, left_zero)
      assert %Maybe.Nothing{} = Prism.preview(15, right_zero)
    end

    test "concat composes multiple prisms like m_concat for Ord" do
      prisms = [
        Prism.filter(&(&1 > 0)),
        Prism.filter(&(rem(&1, 2) == 0)),
        Prism.filter(&(&1 < 100))
      ]

      composed = Prism.concat(prisms)

      # All filters pass
      assert %Maybe.Just{value: 4} = Prism.preview(4, composed)

      # Fails first filter
      assert %Maybe.Nothing{} = Prism.preview(-2, composed)

      # Fails second filter
      assert %Maybe.Nothing{} = Prism.preview(3, composed)

      # Fails third filter
      assert %Maybe.Nothing{} = Prism.preview(200, composed)
    end

    test "concat with empty list returns identity prism" do
      identity = Prism.concat([])

      assert %Maybe.Just{value: 42} = Prism.preview(42, identity)
      assert Prism.review(42, identity) == 42
    end

    test "concat with single prism returns that prism" do
      p = Prism.filter(&(&1 > 10))
      composed = Prism.concat([p])

      assert %Maybe.Just{value: 15} = Prism.preview(15, composed)
      assert %Maybe.Nothing{} = Prism.preview(5, composed)
    end
  end
end
