defmodule Funx.Optics.PrismTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Funx.Optics.Prism

  alias Funx.Monad.Maybe
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Optics.Prism

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule Account, do: defstruct([:name, :type])
  defmodule Payment, do: defstruct([:amount, :account])
  defmodule Profile, do: defstruct([:age, :score])
  defmodule User, do: defstruct([:name, :profile])
  defmodule CreditCard, do: defstruct([:number, :expiry])
  defmodule Check, do: defstruct([:routing_number, :account_number])

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp cc_fixture(number \\ "1234", expiry \\ "12/26") do
    %CreditCard{number: number, expiry: expiry}
  end

  defp check_fixture(routing \\ "111000025", account \\ "987654") do
    %Check{routing_number: routing, account_number: account}
  end

  # ============================================================================
  # Basic Operations Tests
  # ============================================================================

  describe "preview/2" do
    test "returns Just for matching value via key prism" do
      p = Prism.key(:name)
      assert %Just{value: "Alice"} = %{name: "Alice"} |> Prism.preview(p)
    end

    test "returns Nothing for missing key via key prism" do
      p = Prism.key(:name)
      assert %Nothing{} = %{age: 30} |> Prism.preview(p)
    end

    test "returns Nothing for nil" do
      p = Prism.key(:name)
      assert %Nothing{} = nil |> Prism.preview(p)
    end

    test "returns Nothing for empty list" do
      p = Prism.key(:name)
      assert %Nothing{} = [] |> Prism.preview(p)
    end

    test "returns Nothing for function input" do
      p = Prism.key(:name)
      assert %Nothing{} = fn -> :foo end |> Prism.preview(p)
      assert %Nothing{} = fn x -> x end |> Prism.preview(p)
    end
  end

  describe "review/2" do
    test "rebuilds a value using key prism" do
      p = Prism.key(:name)
      assert "Alice" |> Prism.review(p) == %{name: "Alice"}
    end

    test "raises ArgumentError for nil value" do
      p = Prism.key(:name)

      assert_raise ArgumentError,
                   ~r/Cannot review with nil.*prism laws/,
                   fn ->
                     Prism.review(nil, p)
                   end
    end

    test "raises ArgumentError for nil with struct prism" do
      p = Prism.struct(Account)

      assert_raise ArgumentError,
                   ~r/Cannot review with nil.*Just\(nil\) is invalid/,
                   fn ->
                     Prism.review(nil, p)
                   end
    end

    test "raises ArgumentError for nil with path prism" do
      p = Prism.path([:a, :b])

      assert_raise ArgumentError, fn ->
        Prism.review(nil, p)
      end
    end
  end

  # ============================================================================
  # Key Prism Tests
  # ============================================================================

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

  # ============================================================================
  # Path Prism Tests
  # ============================================================================

  describe "path/1 - basic operations" do
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

    test "path prism composes with struct prism" do
      outer = Prism.path([:a, :b])
      inner = Prism.struct(Account)
      p = Prism.compose(outer, inner)

      assert %Just{value: %Account{name: "Alice"}} =
               Prism.preview(%{a: %{b: %Account{name: "Alice"}}}, p)

      assert %Nothing{} = Prism.preview(%{a: %{b: %{name: "Bob"}}}, p)
      assert %Nothing{} = Prism.preview(%{a: %{b: nil}}, p)
    end

    test "review with empty path replaces the entire structure" do
      p = Prism.path([])

      assert Prism.review(123, p) == 123
      assert Prism.review(%{x: 1}, p) == %{x: 1}
      assert Prism.review("new", p) == "new"
    end

    test "preview with empty path is identity (returns Just)" do
      p = Prism.path([])

      # Empty path = compose([]) = identity prism
      assert %Just{value: %{a: 1}} = Prism.preview(%{a: 1}, p)
      assert %Just{value: :anything} = Prism.preview(:anything, p)
    end
  end

  describe "path/1 - with structs" do
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

    test "review constructs fresh nested struct (lawful prism behavior)" do
      p = Prism.path([{User, :profile}, {Profile, :age}])

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

    test "review constructs struct with nested map value" do
      u = %User{name: "A", profile: %Profile{age: 20}}

      # User.name is a simple field, but we can nest further with plain keys
      p = Prism.path([{User, :name}, :foo])

      # Preview fails because name is not a map in the actual data
      assert %Maybe.Nothing{} = Prism.preview(u, p)

      # Review constructs User with nested map in name field
      assert Prism.review("value", p) == %User{name: %{foo: "value"}, profile: nil}
    end

    test "review constructs deeply nested structs from focused value" do
      p = Prism.path([{User, :profile}, {Profile, :score}])

      # Constructs fresh nested structs - other fields are nil
      result = Prism.review(10, p)

      assert match?(%{profile: %{score: 10}}, result)
      assert is_struct(result.profile, Profile)
      assert result == %User{name: nil, profile: %Profile{age: nil, score: 10}}
    end

    test "review with single key and no struct modules creates a plain map" do
      p = Prism.path([:foo])
      assert Prism.review("bar", p) == %{foo: "bar"}
    end

    test "review with multiple keys and no struct modules creates nested maps" do
      p = Prism.path([:a, :b, :c])
      assert Prism.review("value", p) == %{a: %{b: %{c: "value"}}}
    end

    test "path handles struct with nil nested value" do
      u = %User{name: "Charlie", profile: nil}
      p = Prism.path([:profile, :age])

      # Should return Nothing when intermediate value is nil
      assert %Maybe.Nothing{} = Prism.preview(u, p)
    end
  end

  describe "path/1 - naked struct syntax" do
    test "naked struct at end verifies final type" do
      p = Prism.path([:profile, Profile])

      # Preview succeeds when value is correct struct
      user = %User{profile: %Profile{age: 30, score: 100}}
      assert Prism.preview(user, p) == Maybe.just(%Profile{age: 30, score: 100})

      # Preview fails when value is not the struct
      user_with_map = %User{profile: %{age: 30}}
      assert Prism.preview(user_with_map, p) == Maybe.nothing()

      # Review constructs with struct type
      result = Prism.review(%Profile{age: 25, score: 50}, p)
      assert result == %{profile: %Profile{age: 25, score: 50}}
    end

    test "naked struct at beginning verifies root type" do
      p = Prism.path([User, :name])

      # Preview succeeds when root is User struct
      user = %User{name: "Alice", profile: nil}
      assert Prism.preview(user, p) == Maybe.just("Alice")

      # Preview fails when root is not User struct
      plain_map = %{name: "Bob"}
      assert Prism.preview(plain_map, p) == Maybe.nothing()

      # Review constructs User struct
      result = Prism.review("Charlie", p)
      assert result == %User{name: "Charlie", profile: nil}
    end

    test "naked struct in middle verifies intermediate type" do
      p = Prism.path([:user, User, :profile, :age])

      # Preview succeeds when user value is User struct
      data = %{user: %User{name: "Alice", profile: %{age: 30}}}
      assert Prism.preview(data, p) == Maybe.just(30)

      # Preview fails when user value is plain map
      data_with_map = %{user: %{name: "Bob", profile: %{age: 25}}}
      assert Prism.preview(data_with_map, p) == Maybe.nothing()

      # Review constructs with User struct at correct level
      result = Prism.review(35, p)
      assert result == %{user: %User{name: nil, profile: %{age: 35}}}
    end

    test "multiple naked structs verify types at each level" do
      p = Prism.path([User, :profile, Profile, :age])

      # Preview succeeds when both types match
      user = %User{
        name: "Alice",
        profile: %Profile{age: 30, score: 100}
      }

      assert Prism.preview(user, p) == Maybe.just(30)

      # Preview fails when root is wrong type
      assert Prism.preview(%{profile: %Profile{age: 30}}, p) == Maybe.nothing()

      # Preview fails when intermediate is wrong type
      user_wrong_profile = %User{name: "Bob", profile: %{age: 25}}
      assert Prism.preview(user_wrong_profile, p) == Maybe.nothing()

      # Review constructs both struct types
      result = Prism.review(40, p)

      assert result == %User{
               name: nil,
               profile: %Profile{age: 40, score: nil}
             }
    end

    test "mix naked structs with typed field syntax" do
      p = Prism.path([{User, :profile}, Profile, :age])

      # Preview succeeds when types match
      user = %User{
        name: "Alice",
        profile: %Profile{age: 30, score: 100}
      }

      assert Prism.preview(user, p) == Maybe.just(30)

      # Preview fails when profile is not Profile struct
      user_map_profile = %User{name: "Bob", profile: %{age: 25}}
      assert Prism.preview(user_map_profile, p) == Maybe.nothing()

      # Review constructs with both struct types
      result = Prism.review(50, p)

      assert result == %User{
               name: nil,
               profile: %Profile{age: 50, score: nil}
             }
    end

    test "naked struct only (no keys)" do
      p = Prism.path([User])

      # Preview succeeds for User struct
      user = %User{name: "Alice", profile: nil}
      assert Prism.preview(user, p) == Maybe.just(user)

      # Preview fails for non-User
      assert Prism.preview(%{name: "Bob"}, p) == Maybe.nothing()
      assert Prism.preview(%Profile{age: 30}, p) == Maybe.nothing()

      # Review passes through User struct
      input = %User{name: "Charlie", profile: %Profile{age: 25}}
      assert Prism.review(input, p) == input

      # Review constructs User from map
      result = Prism.review(%{name: "Dave"}, p)
      assert result == %User{name: "Dave", profile: nil}
    end

    test "plain keys are not confused with struct modules" do
      # :user and :profile are plain keys, not struct modules
      p = Prism.path([:user, :profile, :age])

      data = %{user: %{profile: %{age: 30}}}
      assert Prism.preview(data, p) == Maybe.just(30)

      # Review creates plain maps
      result = Prism.review(40, p)
      assert result == %{user: %{profile: %{age: 40}}}
    end
  end

  describe "path/1 - edge cases and validation" do
    test "path with single-element list and struct" do
      p = Prism.path([{User, :name}])
      result = Prism.review("David", p)
      assert result == %User{name: "David", profile: nil}
    end

    test "path with mixed struct and plain keys" do
      # When we mix struct-annotated and plain keys,
      # it constructs the struct at the specified level
      p = Prism.path([{User, :profile}, :age, :extra])
      result = Prism.review("value", p)

      # Constructs User struct with nested maps
      assert result == %User{profile: %{age: %{extra: "value"}}, name: nil}
    end

    test "path with struct and valid field" do
      # Struct prism constructs the specified struct type
      p = Prism.path([{User, :name}])
      result = Prism.review("Alice", p)

      # Constructs User struct with the field
      assert result == %User{name: "Alice", profile: nil}
    end

    test "raises when tuple has non-struct module" do
      assert_raise ArgumentError, ~r/:not_a_module.*is not a struct module/, fn ->
        Prism.path([{:not_a_module, :key}])
      end
    end

    test "raises when path contains invalid element" do
      assert_raise ArgumentError,
                   ~r/path\/1 expects atoms or \{Module, :key\} tuples, got: "string"/,
                   fn ->
                     Prism.path(["string"])
                   end

      assert_raise ArgumentError,
                   ~r/path\/1 expects atoms or \{Module, :key\} tuples, got: 123/,
                   fn ->
                     Prism.path([123])
                   end

      assert_raise ArgumentError,
                   ~r/path\/1 expects atoms or \{Module, :key\} tuples, got: %\{\}/,
                   fn ->
                     Prism.path([%{}])
                   end
    end

    test "raises when tuple has non-atom key" do
      assert_raise ArgumentError, ~r/path\/1 expects atoms or \{Module, :key\} tuples/, fn ->
        Prism.path([{User, "name"}])
      end
    end
  end

  # ============================================================================
  # Composition Tests
  # ============================================================================

  describe "compose/2" do
    test "composing struct and key prisms" do
      p1 = Prism.struct(Account)
      p2 = Prism.key(:name)
      p = Prism.compose(p1, p2)

      assert %Just{value: "Alice"} = %Account{name: "Alice"} |> Prism.preview(p)
      assert %Nothing{} = %{name: "Bob"} |> Prism.preview(p)
      assert %Nothing{} = %Account{type: "checking"} |> Prism.preview(p)
    end

    test "composing nested key prisms" do
      p1 = Prism.key(:account)
      p2 = Prism.key(:name)
      p = Prism.compose(p1, p2)

      assert %Just{value: "Alice"} = %{account: %{name: "Alice"}} |> Prism.preview(p)
      assert %Nothing{} = %{account: %{type: "checking"}} |> Prism.preview(p)
      assert %Nothing{} = %{other: "value"} |> Prism.preview(p)
    end

    test "review rebuilds via both prisms" do
      struct_prism = Prism.struct(Account)
      name_prism = Prism.key(:name)
      p = Prism.compose(struct_prism, name_prism)

      assert "Alice" |> Prism.review(p) == %Account{name: "Alice", type: nil}
    end

    test "review composes in reverse order (inner first, then outer)" do
      # Compose struct prism with key prism
      account_name = Prism.compose(Prism.struct(Account), Prism.key(:name))

      # Review applies inner prism first (key: "Alice" -> %{name: "Alice"}),
      # then outer prism (struct: %{name: "Alice"} -> %Account{name: "Alice"})
      assert Prism.review("Alice", account_name) == %Account{name: "Alice", type: nil}
    end
  end

  describe "compose/1 list composition" do
    test "concat composes multiple prisms like m_concat for Ord" do
      prisms = [
        Prism.struct(Payment),
        Prism.key(:account),
        Prism.struct(Account),
        Prism.key(:name)
      ]

      composed = Prism.compose(prisms)

      payment = %Payment{
        amount: 100,
        account: %Account{name: "Alice", type: "checking"}
      }

      # All prisms match
      assert %Maybe.Just{value: "Alice"} = Prism.preview(payment, composed)

      # Fails first prism (not a Payment struct)
      assert %Maybe.Nothing{} = Prism.preview(%{account: %Account{name: "Bob"}}, composed)

      # Fails struct prism (account is not an Account struct)
      payment_with_map = %Payment{amount: 100, account: %{name: "Charlie"}}
      assert %Maybe.Nothing{} = Prism.preview(payment_with_map, composed)

      # Fails key prism (name is nil)
      payment_no_name = %Payment{amount: 100, account: %Account{type: "savings"}}
      assert %Maybe.Nothing{} = Prism.preview(payment_no_name, composed)
    end

    test "compose/1 with empty list returns identity prism" do
      identity = Prism.compose([])

      assert %Maybe.Just{value: 42} = Prism.preview(42, identity)
      assert Prism.review(42, identity) == 42
    end

    test "compose/1 with single prism returns that prism" do
      p = Prism.key(:name)
      composed = Prism.compose([p])

      assert %Maybe.Just{value: "Alice"} = Prism.preview(%{name: "Alice"}, composed)
      assert %Maybe.Nothing{} = Prism.preview(%{age: 30}, composed)
    end
  end

  # ============================================================================
  # Struct Constructor Prism Tests
  # ============================================================================

  describe "struct constructor prism" do
    setup do
      %{
        cc_prism: Prism.struct(CreditCard),
        check_prism: Prism.struct(Check),
        cc: cc_fixture(),
        check: check_fixture()
      }
    end

    test "preview succeeds for matching struct", %{cc_prism: p, cc: cc} do
      assert Prism.preview(cc, p) == Maybe.just(cc)
    end

    test "preview fails for non-matching struct", %{cc_prism: p, check: check} do
      assert Prism.preview(check, p) == Maybe.nothing()
    end

    test "preview fails for non-struct input", %{cc_prism: p} do
      assert Prism.preview(:not_a_struct, p) == Maybe.nothing()
    end

    test "review returns the struct unchanged", %{cc_prism: p, cc: cc} do
      assert Prism.review(cc, p) == cc
    end

    test "review does not construct or wrap", %{check_prism: p, check: check} do
      assert Prism.review(check, p) == check
    end

    test "prism law: preview(review(x)) == Just(x)", %{cc_prism: p, cc: cc} do
      assert Prism.preview(Prism.review(cc, p), p) == Maybe.just(cc)
    end

    test "composed with key: preview extracts nested value", %{cc_prism: cc_p, cc: cc} do
      cc_number_prism = Prism.compose(cc_p, Prism.key(:number))
      assert Prism.preview(cc, cc_number_prism) == Maybe.just("1234")
    end

    test "composed with key: preview fails on wrong struct", %{cc_prism: cc_p, check: check} do
      cc_number_prism = Prism.compose(cc_p, Prism.key(:number))
      assert Prism.preview(check, cc_number_prism) == Maybe.nothing()
    end

    test "composed with key: review constructs struct from map", %{cc_prism: cc_p} do
      cc_number_prism = Prism.compose(cc_p, Prism.key(:number))
      result = Prism.review("5678", cc_number_prism)
      assert result == %CreditCard{number: "5678", expiry: nil}
    end

    test "composed with key: law preview(review(x)) == Just(x)", %{cc_prism: cc_p} do
      cc_number_prism = Prism.compose(cc_p, Prism.key(:number))
      reviewed = Prism.review("5678", cc_number_prism)
      assert Prism.preview(reviewed, cc_number_prism) == Maybe.just("5678")
    end

    test "composed with key: law preserves focus through round-trip", %{cc_prism: cc_p, cc: cc} do
      cc_number_prism = Prism.compose(cc_p, Prism.key(:number))

      assert Prism.preview(cc, cc_number_prism) == Maybe.just("1234")

      reviewed = Prism.review("1234", cc_number_prism)
      assert Prism.preview(reviewed, cc_number_prism) == Maybe.just("1234")
    end
  end

  # ============================================================================
  # Monoid Structure Tests
  # ============================================================================

  describe "Monoid structure via PrismCompose" do
    alias Funx.Monoid.Optics.PrismCompose

    test "prisms form a monoid under composition via PrismCompose" do
      import Funx.Monoid

      p1 = PrismCompose.new(Prism.struct(Account))
      p2 = PrismCompose.new(Prism.key(:name))

      # Composition via Monoid.append
      composed = append(p1, p2) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: "Alice"} = Prism.preview(%Account{name: "Alice"}, composed)
      assert %Maybe.Nothing{} = Prism.preview(%{name: "Bob"}, composed)
      assert %Maybe.Nothing{} = Prism.preview(%Account{type: "checking"}, composed)
    end

    test "identity prism preserves values" do
      import Funx.Monoid

      id = empty(%PrismCompose{})
      p = PrismCompose.new(Prism.key(:name))

      # Left identity: append(id, p) == p
      left = append(id, p) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: "Alice"} = Prism.preview(%{name: "Alice"}, left)
      assert %Maybe.Nothing{} = Prism.preview(%{age: 30}, left)

      # Right identity: append(p, id) == p
      right = append(p, id) |> PrismCompose.unwrap()
      assert %Maybe.Just{value: "Alice"} = Prism.preview(%{name: "Alice"}, right)
      assert %Maybe.Nothing{} = Prism.preview(%{age: 30}, right)
    end

    test "composition is associative" do
      import Funx.Monoid

      p1 = PrismCompose.new(Prism.key(:payment))
      p2 = PrismCompose.new(Prism.key(:account))
      p3 = PrismCompose.new(Prism.key(:name))

      # (p1 . p2) . p3 == p1 . (p2 . p3)
      left_assoc = append(append(p1, p2), p3) |> PrismCompose.unwrap()
      right_assoc = append(p1, append(p2, p3)) |> PrismCompose.unwrap()

      data = %{payment: %{account: %{name: "Alice"}}}

      # Test with matching data
      assert %Maybe.Just{value: "Alice"} = Prism.preview(data, left_assoc)
      assert %Maybe.Just{value: "Alice"} = Prism.preview(data, right_assoc)

      # Test with data missing first key
      assert %Maybe.Nothing{} = Prism.preview(%{other: "value"}, left_assoc)
      assert %Maybe.Nothing{} = Prism.preview(%{other: "value"}, right_assoc)

      # Test with data missing second key
      assert %Maybe.Nothing{} = Prism.preview(%{payment: %{other: "value"}}, left_assoc)
      assert %Maybe.Nothing{} = Prism.preview(%{payment: %{other: "value"}}, right_assoc)

      # Test with data missing third key
      assert %Maybe.Nothing{} =
               Prism.preview(%{payment: %{account: %{other: "value"}}}, left_assoc)

      assert %Maybe.Nothing{} =
               Prism.preview(%{payment: %{account: %{other: "value"}}}, right_assoc)
    end
  end

  # ============================================================================
  # Malformed Prism Construction Tests
  # ============================================================================

  describe "malformed prism construction" do
    test "key/1 raises for non-atom" do
      assert_raise FunctionClauseError, fn ->
        Prism.key("not_an_atom")
      end

      assert_raise FunctionClauseError, fn ->
        Prism.key(123)
      end
    end

    test "struct/1 raises for non-struct module" do
      assert_raise ArgumentError,
                   ~r/String is not a struct module/,
                   fn ->
                     Prism.struct(String)
                   end

      assert_raise ArgumentError,
                   ~r/Enum is not a struct module/,
                   fn ->
                     Prism.struct(Enum)
                   end
    end

    test "struct/1 raises for non-module atom" do
      assert_raise ArgumentError,
                   ~r/:not_a_module is not a struct module/,
                   fn ->
                     Prism.struct(:not_a_module)
                   end
    end

    test "make/2 raises for non-function arguments" do
      assert_raise FunctionClauseError, fn ->
        Prism.make("not a function", fn x -> x end)
      end

      assert_raise FunctionClauseError, fn ->
        Prism.make(fn x -> x end, "not a function")
      end
    end

    test "make/2 raises for wrong arity" do
      assert_raise FunctionClauseError, fn ->
        # preview arity 0, should be 1
        Prism.make(fn -> nil end, fn x -> x end)
      end

      assert_raise FunctionClauseError, fn ->
        # review arity 0, should be 1
        Prism.make(fn x -> x end, fn -> nil end)
      end
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: preview-review laws" do
    property "preview(review(a, prism), prism) == Just(a) for key prisms" do
      check all(
              key <- atom(:alphanumeric),
              value <- one_of([integer(), string(:alphanumeric), boolean()])
            ) do
        prism = Prism.key(key)

        # Review a value, then preview it - should get Just(value) back
        reviewed = Prism.review(value, prism)
        result = Prism.preview(reviewed, prism)

        assert result == Maybe.just(value)
      end
    end

    property "preview(review(a, prism), prism) == Just(a) for path prisms" do
      check all(
              key1 <- atom(:alphanumeric),
              key2 <- atom(:alphanumeric),
              key3 <- atom(:alphanumeric),
              value <- one_of([integer(), string(:alphanumeric)])
            ) do
        prism = Prism.path([key1, key2, key3])

        reviewed = Prism.review(value, prism)
        result = Prism.preview(reviewed, prism)

        assert result == Maybe.just(value)
      end
    end

    property "preview(review(a, prism), prism) == Just(a) for composed prisms" do
      check all(
              key1 <- atom(:alphanumeric),
              key2 <- atom(:alphanumeric),
              value <- integer(0..1000)
            ) do
        outer = Prism.key(key1)
        inner = Prism.key(key2)
        prism = Prism.compose(outer, inner)

        reviewed = Prism.review(value, prism)
        result = Prism.preview(reviewed, prism)

        assert result == Maybe.just(value)
      end
    end

    property "struct prism satisfies preview-review law" do
      check all(
              name <- string(:alphanumeric),
              number <- string(:alphanumeric, min_length: 4, max_length: 16)
            ) do
        prism = Prism.struct(CreditCard)
        cc = %CreditCard{number: number, expiry: name}

        reviewed = Prism.review(cc, prism)
        result = Prism.preview(reviewed, prism)

        assert result == Maybe.just(cc)
      end
    end

    property "composed struct and key prism satisfies preview-review law" do
      check all(value <- string(:alphanumeric)) do
        prism = Prism.compose(Prism.struct(Account), Prism.key(:name))

        reviewed = Prism.review(value, prism)
        result = Prism.preview(reviewed, prism)

        assert result == Maybe.just(value)
        # Also verify the structure is correct
        assert reviewed == %Account{name: value, type: nil}
      end
    end
  end

  describe "property: Nothing behavior" do
    property "preview returns Nothing for maps missing the key" do
      check all(
              target_key <- atom(:alphanumeric),
              other_key <- atom(:alphanumeric),
              value <- integer()
            ) do
        # Only test when keys are different
        if target_key != other_key do
          prism = Prism.key(target_key)
          data = %{other_key => value}

          result = Prism.preview(data, prism)

          assert result == Maybe.nothing()
        end
      end
    end

    property "preview returns Nothing when value is nil" do
      check all(key <- atom(:alphanumeric)) do
        prism = Prism.key(key)
        data = %{key => nil}

        result = Prism.preview(data, prism)

        assert result == Maybe.nothing()
      end
    end

    property "preview on nested paths returns Nothing if any intermediate key is missing" do
      check all(
              key1 <- atom(:alphanumeric),
              key2 <- atom(:alphanumeric),
              key3 <- atom(:alphanumeric),
              other_key <- atom(:alphanumeric),
              value <- integer()
            ) do
        # Only test when keys are different
        if key2 != other_key do
          prism = Prism.path([key1, key2, key3])

          # Create data where first level exists but second level key is different
          data = %{key1 => %{other_key => value}}

          result = Prism.preview(data, prism)

          assert result == Maybe.nothing()
        end
      end
    end
  end

  describe "property: identity prism" do
    property "identity prism satisfies preview(x) == Just(x) for non-nil values" do
      check all(value <- one_of([integer(), string(:alphanumeric), boolean()])) do
        id_prism = Prism.compose([])

        result = Prism.preview(value, id_prism)

        assert result == Maybe.just(value)
      end
    end

    property "identity prism satisfies review(x) == x" do
      check all(
              value <-
                one_of([
                  integer(),
                  string(:alphanumeric),
                  map_of(atom(:alphanumeric), integer())
                ])
            ) do
        id_prism = Prism.compose([])

        result = Prism.review(value, id_prism)

        assert result == value
      end
    end
  end

  describe "property: composition laws" do
    property "composition is associative for prisms" do
      check all(
              key1 <- atom(:alphanumeric),
              key2 <- atom(:alphanumeric),
              key3 <- atom(:alphanumeric),
              value <- integer(0..1000)
            ) do
        p1 = Prism.key(key1)
        p2 = Prism.key(key2)
        p3 = Prism.key(key3)

        # (p1 . p2) . p3 vs p1 . (p2 . p3)
        left_assoc = Prism.compose(Prism.compose(p1, p2), p3)
        right_assoc = Prism.compose(p1, Prism.compose(p2, p3))

        # Both should review to the same structure
        reviewed_left = Prism.review(value, left_assoc)
        reviewed_right = Prism.review(value, right_assoc)

        assert reviewed_left == reviewed_right

        # Both should preview the same value
        assert Prism.preview(reviewed_left, left_assoc) == Maybe.just(value)
        assert Prism.preview(reviewed_right, right_assoc) == Maybe.just(value)
      end
    end

    property "path prism with single key behaves like key prism" do
      check all(
              key <- atom(:alphanumeric),
              value <- integer(0..1000)
            ) do
        path_prism = Prism.path([key])
        key_prism = Prism.key(key)

        # Both should review to the same structure
        assert Prism.review(value, path_prism) == Prism.review(value, key_prism)

        # Both should preview the same from matching data
        data = %{key => value}
        assert Prism.preview(data, path_prism) == Prism.preview(data, key_prism)
      end
    end
  end

  describe "property: review structure" do
    property "review creates minimal structure with only specified keys" do
      check all(
              key <- atom(:alphanumeric),
              value <- integer()
            ) do
        prism = Prism.key(key)
        reviewed = Prism.review(value, prism)

        # Should create a map with only the specified key
        assert reviewed == %{key => value}
        assert Map.keys(reviewed) == [key]
      end
    end

    property "multiple reviews with different values replace the focused value" do
      check all(
              key <- atom(:alphanumeric),
              value1 <- integer(0..500),
              value2 <- integer(501..1000)
            ) do
        prism = Prism.key(key)

        # Review with first value
        result1 = Prism.review(value1, prism)

        # Review with second value (creates fresh structure)
        result2 = Prism.review(value2, prism)

        # Both should create independent structures
        assert Prism.preview(result1, prism) == Maybe.just(value1)
        assert Prism.preview(result2, prism) == Maybe.just(value2)
        assert result1 != result2
      end
    end
  end
end
