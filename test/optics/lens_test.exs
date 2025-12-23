defmodule Funx.Optics.LensTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Funx.Optics.Lens

  alias Funx.Optics.Lens

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule User, do: defstruct([:name, :age, :email])
  defmodule Profile, do: defstruct([:user, :score])
  defmodule Address, do: defstruct([:street, :city, :zip])
  defmodule Company, do: defstruct([:name, :address])
  defmodule Employee, do: defstruct([:user, :company, :salary])

  # ============================================================================
  # Basic Operations Tests
  # ============================================================================

  describe "view!/2" do
    test "retrieves the focused value" do
      lens = Lens.key(:name)
      assert %{name: "Alice"} |> Lens.view!(lens) == "Alice"
    end

    test "views nested values with composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      data = %{profile: %{score: 5}}

      assert data |> Lens.view!(lens) == 5
    end

    test "views deeply nested values with path/1" do
      lens = Lens.path([:stats, :wins])
      assert %{stats: %{wins: 2}} |> Lens.view!(lens) == 2
    end
  end

  describe "set!/3" do
    test "replaces the focused value" do
      lens = Lens.key(:count)
      result = %{count: 3} |> Lens.set!(lens, 10)
      assert result == %{count: 10}
    end

    test "sets nested values with composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      data = %{profile: %{score: 5}}
      updated = data |> Lens.set!(lens, 9)

      assert updated == %{profile: %{score: 9}}
    end

    test "sets deeply nested values with path/1" do
      lens = Lens.path([:stats, :losses])

      updated =
        %{stats: %{losses: 1}}
        |> Lens.set!(lens, 4)

      assert updated == %{stats: %{losses: 4}}
    end
  end

  describe "over!/3" do
    test "updates the focused value with a function" do
      lens = Lens.key(:age)

      data = %{age: 40}

      updated =
        data
        |> Lens.over!(lens, fn a -> a + 1 end)

      assert updated == %{age: 41}
    end

    test "works through composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      data = %{profile: %{score: 10}}

      updated =
        data
        |> Lens.over!(lens, fn n -> n * 2 end)

      assert updated == %{profile: %{score: 20}}
    end

    test "works through path/1" do
      lens = Lens.path([:stats, :wins])

      data = %{stats: %{wins: 3}}

      updated =
        data
        |> Lens.over!(lens, fn n -> n + 5 end)

      assert updated == %{stats: %{wins: 8}}
    end
  end

  # ============================================================================
  # Composition Tests
  # ============================================================================

  describe "compose/2" do
    test "focuses through nested structures" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      data = %{profile: %{score: 5}}

      assert data |> Lens.view!(lens) == 5

      updated = data |> Lens.set!(lens, 9)
      assert updated == %{profile: %{score: 9}}
    end

    test "behaves identically to nested path when structure matches" do
      a = Lens.key(:outer)
      b = Lens.key(:inner)
      composed = Lens.compose(a, b)

      path_lens = Lens.path([:outer, :inner])

      data = %{outer: %{inner: 7}}

      assert data |> Lens.view!(composed) == data |> Lens.view!(path_lens)

      updated1 = data |> Lens.set!(composed, 9)
      updated2 = data |> Lens.set!(path_lens, 9)

      assert updated1 == updated2
    end

    test "can be chained multiple times" do
      lens =
        Lens.key(:company)
        |> Lens.compose(Lens.key(:address))
        |> Lens.compose(Lens.key(:street))

      employee = %Employee{
        user: %User{name: "Bob", age: 25, email: "bob@example.com"},
        company: %Company{
          name: "Tech Inc",
          address: %Address{street: "456 Oak Ave", city: "LA", zip: "90001"}
        },
        salary: 80_000
      }

      assert Lens.view!(employee, lens) == "456 Oak Ave"

      updated = Lens.set!(employee, lens, "789 Pine St")

      assert updated.company.address.street == "789 Pine St"
      assert updated.__struct__ == Employee
      assert updated.company.__struct__ == Company
      assert updated.company.address.__struct__ == Address
    end
  end

  describe "compose/1 list composition" do
    test "composes multiple lenses" do
      lenses = [
        Lens.key(:user),
        Lens.key(:profile),
        Lens.key(:age)
      ]

      composed = Lens.compose(lenses)

      data = %{user: %{profile: %{age: 25, name: "Alice"}}}

      assert Lens.view!(data, composed) == 25

      updated = Lens.set!(data, composed, 26)
      assert updated.user.profile.age == 26
      assert updated.user.profile.name == "Alice"
    end

    test "with empty list returns identity lens" do
      identity = Lens.compose([])

      data = %{name: "Alice", age: 30}

      # Identity lens views the whole structure
      assert Lens.view!(data, identity) == data

      # Identity lens replaces the whole structure
      new_data = %{name: "Bob", age: 25}
      assert Lens.set!(data, identity, new_data) == new_data
    end

    test "with single lens returns that lens" do
      l = Lens.key(:name)
      composed = Lens.compose([l])

      data = %{name: "Alice", age: 30}

      assert Lens.view!(data, composed) == "Alice"
      assert Lens.set!(data, composed, "Bob") == %{name: "Bob", age: 30}
    end

    test "composes through deeply nested structs" do
      lenses = [
        Lens.key(:company),
        Lens.key(:address),
        Lens.key(:city)
      ]

      lens = Lens.compose(lenses)

      employee = %Employee{
        user: %User{name: "Alice", age: 30, email: "alice@example.com"},
        company: %Company{
          name: "Acme Corp",
          address: %Address{street: "123 Main St", city: "NYC", zip: "10001"}
        },
        salary: 100_000
      }

      # View deeply nested value
      assert Lens.view!(employee, lens) == "NYC"

      # Update deeply nested value
      updated = Lens.set!(employee, lens, "SF")

      # Verify the update
      assert updated.company.address.city == "SF"

      # Verify all struct types are preserved
      assert updated.__struct__ == Employee
      assert updated.company.__struct__ == Company
      assert updated.company.address.__struct__ == Address

      # Verify other fields are untouched
      assert updated.user == employee.user
      assert updated.salary == employee.salary
      assert updated.company.name == "Acme Corp"
      assert updated.company.address.street == "123 Main St"
      assert updated.company.address.zip == "10001"
    end
  end

  describe "path/1" do
    test "gets nested values" do
      lens = Lens.path([:stats, :wins])
      assert %{stats: %{wins: 2}} |> Lens.view!(lens) == 2
    end

    test "sets nested values" do
      lens = Lens.path([:stats, :losses])

      updated =
        %{stats: %{losses: 1}}
        |> Lens.set!(lens, 4)

      assert updated == %{stats: %{losses: 4}}
    end

    test "empty path behaves as identity lens" do
      lens = Lens.path([])
      data = %{name: "Alice", age: 30}

      # Views the whole structure
      assert Lens.view!(data, lens) == data

      # Sets the whole structure
      new_data = %{name: "Bob", age: 25}
      assert Lens.set!(data, lens, new_data) == new_data
    end

    test "empty path with over!/3 replaces entire structure" do
      lens = Lens.path([])
      data = %{count: 5}

      result = Lens.over!(data, lens, fn d -> Map.update!(d, :count, &(&1 * 2)) end)
      assert result == %{count: 10}
    end
  end

  # ============================================================================
  # Struct Support Tests
  # ============================================================================

  describe "struct support" do
    test "key/1 views a struct field" do
      lens = Lens.key(:name)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      assert Lens.view!(user, lens) == "Alice"
    end

    test "key/1 sets a struct field while preserving struct type" do
      lens = Lens.key(:name)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      updated = Lens.set!(user, lens, "Bob")

      assert updated == %User{name: "Bob", age: 30, email: "alice@example.com"}
      assert updated.__struct__ == User
    end

    test "key/1 preserves other struct fields when updating" do
      lens = Lens.key(:age)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      updated = Lens.set!(user, lens, 31)

      assert updated.name == "Alice"
      assert updated.age == 31
      assert updated.email == "alice@example.com"
    end

    test "compose/2 works with nested structs" do
      user_lens = Lens.key(:user)
      name_lens = Lens.key(:name)
      lens = Lens.compose(user_lens, name_lens)

      profile = %Profile{
        user: %User{name: "Alice", age: 30, email: "alice@example.com"},
        score: 100
      }

      assert Lens.view!(profile, lens) == "Alice"

      updated = Lens.set!(profile, lens, "Bob")
      assert updated.user.name == "Bob"
      assert updated.user.age == 30
      assert updated.__struct__ == Profile
      assert updated.user.__struct__ == User
    end

    test "compose/2 preserves all struct types in nested update" do
      user_lens = Lens.key(:user)
      email_lens = Lens.key(:email)
      lens = Lens.compose(user_lens, email_lens)

      profile = %Profile{
        user: %User{name: "Alice", age: 30, email: "alice@example.com"},
        score: 100
      }

      updated = Lens.set!(profile, lens, "bob@example.com")

      # Check the nested user struct is preserved
      assert updated.user.__struct__ == User
      assert updated.user.email == "bob@example.com"
      assert updated.user.name == "Alice"
      assert updated.user.age == 30

      # Check the outer profile struct is preserved
      assert updated.__struct__ == Profile
      assert updated.score == 100
    end

    test "compose identity lens with key lens on struct" do
      identity = Lens.make(fn s -> s end, fn _s, a -> a end)
      name_lens = Lens.key(:name)
      lens = Lens.compose(identity, name_lens)

      user = %User{name: "Eve", age: 28, email: "eve@example.com"}

      assert Lens.view!(user, lens) == "Eve"

      updated = Lens.set!(user, lens, "Frank")
      assert updated.__struct__ == User
      assert updated.name == "Frank"
      assert updated.age == 28
    end

    test "multiple independent lens updates preserve struct" do
      user = %User{name: "Grace", age: 40, email: "grace@example.com"}

      name_lens = Lens.key(:name)
      age_lens = Lens.key(:age)
      email_lens = Lens.key(:email)

      # Apply multiple updates
      updated =
        user
        |> Lens.set!(name_lens, "Hannah")
        |> Lens.set!(age_lens, 41)
        |> Lens.set!(email_lens, "hannah@example.com")

      assert updated.__struct__ == User
      assert updated.name == "Hannah"
      assert updated.age == 41
      assert updated.email == "hannah@example.com"
    end

    test "deeply nested struct composition with compose/1" do
      # Test 4-level deep nesting
      employee = %Employee{
        user: %User{name: "Ian", age: 45, email: "ian@example.com"},
        company: %Company{
          name: "Deep Corp",
          address: %Address{street: "999 Deep Ln", city: "Boston", zip: "02101"}
        },
        salary: 120_000
      }

      # Compose to the deepest level
      zip_lens = Lens.compose([Lens.key(:company), Lens.key(:address), Lens.key(:zip)])

      assert Lens.view!(employee, zip_lens) == "02101"

      updated = Lens.set!(employee, zip_lens, "02102")

      # All types preserved through 4 levels
      assert updated.__struct__ == Employee
      assert updated.company.__struct__ == Company
      assert updated.company.address.__struct__ == Address
      assert updated.company.address.zip == "02102"

      # Everything else untouched
      assert updated.user.name == "Ian"
      assert updated.salary == 120_000
      assert updated.company.name == "Deep Corp"
      assert updated.company.address.city == "Boston"
    end

    test "mixing struct and map lenses preserves struct types" do
      # Profile has a User struct, but User might have a map field
      user_with_metadata = %User{
        name: "Charlie",
        age: 35,
        email: "charlie@example.com"
      }

      profile_with_meta = %{
        profile: %Profile{user: user_with_metadata, score: 50},
        metadata: %{last_login: "2024-01-01"}
      }

      # Compose through map -> struct -> struct field
      lens =
        Lens.key(:profile)
        |> Lens.compose(Lens.key(:user))
        |> Lens.compose(Lens.key(:name))

      assert Lens.view!(profile_with_meta, lens) == "Charlie"

      updated = Lens.set!(profile_with_meta, lens, "David")

      # Struct types preserved
      assert updated.profile.__struct__ == Profile
      assert updated.profile.user.__struct__ == User
      assert updated.profile.user.name == "David"

      # Other fields untouched
      assert updated.profile.score == 50
      assert updated.metadata.last_login == "2024-01-01"
    end

    test "over!/3 preserves struct type when updating a struct field" do
      lens = Lens.key(:age)

      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      updated =
        user
        |> Lens.over!(lens, fn a -> a + 1 end)

      assert updated.__struct__ == User
      assert updated.age == 31
      assert updated.name == "Alice"
      assert updated.email == "alice@example.com"
    end

    test "over!/3 works through nested structs with compose/2" do
      user_lens = Lens.key(:user)
      age_lens = Lens.key(:age)
      lens = Lens.compose(user_lens, age_lens)

      profile = %Profile{
        user: %User{name: "Bob", age: 25, email: "bob@example.com"},
        score: 100
      }

      updated =
        profile
        |> Lens.over!(lens, fn a -> a + 10 end)

      assert updated.__struct__ == Profile
      assert updated.user.__struct__ == User
      assert updated.user.age == 35
      assert updated.user.name == "Bob"
      assert updated.score == 100
    end

    test "over!/3 deeply nested struct update with compose/1" do
      lens =
        Lens.compose([
          Lens.key(:company),
          Lens.key(:address),
          Lens.key(:zip)
        ])

      employee = %Employee{
        user: %User{name: "Ian", age: 45, email: "ian@example.com"},
        company: %Company{
          name: "Deep Corp",
          address: %Address{street: "999 Deep Ln", city: "Boston", zip: "02101"}
        },
        salary: 120_000
      }

      updated =
        employee
        |> Lens.over!(lens, fn _ -> "99999" end)

      assert updated.company.address.zip == "99999"
      assert updated.__struct__ == Employee
      assert updated.company.__struct__ == Company
      assert updated.company.address.__struct__ == Address
      assert updated.user == employee.user
      assert updated.salary == 120_000
    end
  end

  describe "struct edge cases" do
    test "setting non-existent field on struct raises KeyError" do
      lens = Lens.key(:nonexistent)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      assert_raise KeyError, fn ->
        Lens.set!(user, lens, "value")
      end
    end

    test "viewing non-existent field on struct raises KeyError" do
      lens = Lens.key(:missing)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      assert_raise KeyError, fn ->
        Lens.view!(user, lens)
      end
    end

    test "safe operations with non-existent struct field" do
      lens = Lens.key(:invalid)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      result = Lens.view(user, lens)
      assert %Funx.Monad.Either.Left{left: %KeyError{key: :invalid}} = result

      result = Lens.set(user, lens, "value")
      assert %Funx.Monad.Either.Left{left: %KeyError{key: :invalid}} = result
    end
  end

  # ============================================================================
  # Monoid Structure Tests
  # ============================================================================

  describe "Monoid structure via LensCompose" do
    alias Funx.Monoid.Optics.LensCompose

    test "lenses form a monoid under composition via LensCompose" do
      import Funx.Monoid

      l1 = LensCompose.new(Lens.key(:profile))
      l2 = LensCompose.new(Lens.key(:score))

      # Composition via Monoid.append
      composed = append(l1, l2) |> LensCompose.unwrap()

      data = %{profile: %{score: 42}}
      assert Lens.view!(data, composed) == 42

      updated = Lens.set!(data, composed, 99)
      assert updated == %{profile: %{score: 99}}
    end

    test "identity lens preserves structure" do
      import Funx.Monoid

      id = empty(%LensCompose{})
      l = LensCompose.new(Lens.key(:name))

      data = %{name: "Alice", age: 30}

      # Left identity: append(id, l) == l
      left = append(id, l) |> LensCompose.unwrap()
      assert Lens.view!(data, left) == "Alice"
      assert Lens.set!(data, left, "Bob") == %{name: "Bob", age: 30}

      # Right identity: append(l, id) == l
      right = append(l, id) |> LensCompose.unwrap()
      assert Lens.view!(data, right) == "Alice"
      assert Lens.set!(data, right, "Bob") == %{name: "Bob", age: 30}
    end

    test "composition is associative" do
      import Funx.Monoid

      l1 = LensCompose.new(Lens.key(:company))
      l2 = LensCompose.new(Lens.key(:address))
      l3 = LensCompose.new(Lens.key(:city))

      # (l1 . l2) . l3 == l1 . (l2 . l3)
      left_assoc = append(append(l1, l2), l3) |> LensCompose.unwrap()
      right_assoc = append(l1, append(l2, l3)) |> LensCompose.unwrap()

      data = %{
        company: %{
          address: %{city: "NYC", street: "Main St"}
        }
      }

      # Both should view the same value
      assert Lens.view!(data, left_assoc) == "NYC"
      assert Lens.view!(data, right_assoc) == "NYC"

      # Both should set the same way
      updated_left = Lens.set!(data, left_assoc, "SF")
      updated_right = Lens.set!(data, right_assoc, "SF")
      assert updated_left == updated_right
      assert updated_left.company.address.city == "SF"
    end

    test "monoid laws hold with struct composition" do
      import Funx.Monoid

      l1 = LensCompose.new(Lens.key(:user))
      l2 = LensCompose.new(Lens.key(:name))

      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      profile = %Profile{user: user, score: 100}

      # Compose and test
      composed = append(l1, l2) |> LensCompose.unwrap()

      assert Lens.view!(profile, composed) == "Alice"

      updated = Lens.set!(profile, composed, "Bob")
      assert updated.user.name == "Bob"
      assert updated.__struct__ == Profile
      assert updated.user.__struct__ == User
    end
  end

  # ============================================================================
  # Safe Operations Tests
  # ============================================================================

  describe "safe view/3" do
    test ":either mode returns Right on success, Left on error" do
      lens = Lens.key(:name)

      assert %Funx.Monad.Either.Right{right: "Alice"} = Lens.view(%{name: "Alice"}, lens)
      assert %Funx.Monad.Either.Left{left: %KeyError{}} = Lens.view(%{}, lens)
    end

    test ":tuple mode returns {:ok, value} on success, {:error, exception} on error" do
      lens = Lens.key(:name)

      assert {:ok, "Bob"} = Lens.view(%{name: "Bob"}, lens, as: :tuple)
      assert {:error, %KeyError{key: :name}} = Lens.view(%{}, lens, as: :tuple)
    end

    test ":raise mode returns value on success, raises on error" do
      lens = Lens.key(:name)

      assert "Charlie" = Lens.view(%{name: "Charlie"}, lens, as: :raise)

      assert_raise KeyError, fn ->
        Lens.view(%{}, lens, as: :raise)
      end
    end

    test "works with composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      result = Lens.view(%{profile: %{score: 100}}, lens)
      assert %Funx.Monad.Either.Right{right: 100} = result

      result = Lens.view(%{}, lens)
      assert %Funx.Monad.Either.Left{} = result
    end

    test "works with path lenses" do
      lens = Lens.path([:user, :name])

      result = Lens.view(%{user: %{name: "Dave"}}, lens)
      assert %Funx.Monad.Either.Right{right: "Dave"} = result

      result = Lens.view(%{}, lens)
      assert %Funx.Monad.Either.Left{} = result
    end
  end

  describe "safe set/4" do
    test ":either mode returns Right on success, Left on error" do
      lens = Lens.key(:age)

      assert %Funx.Monad.Either.Right{right: %{age: 31}} = Lens.set(%{age: 30}, lens, 31)
      assert %Funx.Monad.Either.Left{left: %KeyError{}} = Lens.set(%{}, lens, 31)
    end

    test ":tuple mode returns {:ok, updated} on success, {:error, exception} on error" do
      lens = Lens.key(:count)

      assert {:ok, %{count: 10}} = Lens.set(%{count: 5}, lens, 10, as: :tuple)
      assert {:error, %KeyError{key: :count}} = Lens.set(%{}, lens, 10, as: :tuple)
    end

    test ":raise mode returns updated value on success, raises on error" do
      lens = Lens.key(:name)

      assert %{name: "Bob"} = Lens.set(%{name: "Alice"}, lens, "Bob", as: :raise)

      assert_raise KeyError, fn ->
        Lens.set(%{}, lens, "Alice", as: :raise)
      end
    end

    test "works with composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      result = Lens.set(%{profile: %{score: 50}}, lens, 100)
      assert %Funx.Monad.Either.Right{right: %{profile: %{score: 100}}} = result

      result = Lens.set(%{}, lens, 100)
      assert %Funx.Monad.Either.Left{} = result
    end

    test "works with path lenses" do
      lens = Lens.path([:stats, :wins])

      result = Lens.set(%{stats: %{wins: 5}}, lens, 10)
      assert %Funx.Monad.Either.Right{right: %{stats: %{wins: 10}}} = result

      result = Lens.set(%{}, lens, 10)
      assert %Funx.Monad.Either.Left{} = result
    end

    test "preserves struct types on success" do
      lens = Lens.key(:name)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      result = Lens.set(user, lens, "Bob")
      assert %Funx.Monad.Either.Right{right: updated} = result
      assert updated.__struct__ == User
      assert updated.name == "Bob"
    end
  end

  describe "safe over/4" do
    test ":either mode returns Right on success, Left on error" do
      lens = Lens.key(:age)

      assert %Funx.Monad.Either.Right{right: %{age: 31}} =
               Lens.over(%{age: 30}, lens, fn a -> a + 1 end)

      assert %Funx.Monad.Either.Left{left: %KeyError{}} = Lens.over(%{}, lens, fn a -> a + 1 end)
    end

    test ":tuple mode returns {:ok, updated} on success, {:error, exception} on error" do
      lens = Lens.key(:score)

      assert {:ok, %{score: 15}} = Lens.over(%{score: 10}, lens, fn s -> s + 5 end, as: :tuple)

      assert {:error, %KeyError{key: :score}} =
               Lens.over(%{}, lens, fn s -> s + 5 end, as: :tuple)
    end

    test ":raise mode returns updated value on success, raises on error" do
      lens = Lens.key(:value)

      assert %{value: 20} = Lens.over(%{value: 10}, lens, fn v -> v * 2 end, as: :raise)

      assert_raise KeyError, fn ->
        Lens.over(%{}, lens, fn v -> v + 1 end, as: :raise)
      end
    end

    test "works with composed lenses" do
      outer = Lens.key(:profile)
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      result = Lens.over(%{profile: %{score: 50}}, lens, fn s -> s * 2 end)
      assert %Funx.Monad.Either.Right{right: %{profile: %{score: 100}}} = result

      result = Lens.over(%{}, lens, fn s -> s * 2 end)
      assert %Funx.Monad.Either.Left{} = result
    end

    test "works with path lenses" do
      lens = Lens.path([:stats, :wins])

      result = Lens.over(%{stats: %{wins: 5}}, lens, fn w -> w + 3 end)
      assert %Funx.Monad.Either.Right{right: %{stats: %{wins: 8}}} = result

      result = Lens.over(%{}, lens, fn w -> w + 3 end)
      assert %Funx.Monad.Either.Left{} = result
    end

    test "preserves struct types on success" do
      lens = Lens.key(:age)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      result = Lens.over(user, lens, fn a -> a + 1 end)
      assert %Funx.Monad.Either.Right{right: updated} = result
      assert updated.__struct__ == User
      assert updated.age == 31
    end

    test "applies function correctly through nested structures" do
      lens = Lens.path([:user, :age])
      data = %{user: %{name: "Bob", age: 25}}

      result = Lens.over(data, lens, fn age -> age + 10 end)
      assert %Funx.Monad.Either.Right{right: updated} = result
      assert updated.user.age == 35
      assert updated.user.name == "Bob"
    end
  end

  describe "function errors in over/4" do
    test "over/4 catches exceptions from user function with :either mode" do
      lens = Lens.key(:value)
      data = %{value: 10}

      result = Lens.over(data, lens, fn _v -> raise "oops!" end)
      assert %Funx.Monad.Either.Left{left: %RuntimeError{message: "oops!"}} = result
    end

    test "over/4 catches exceptions from user function with :tuple mode" do
      lens = Lens.key(:value)
      data = %{value: 10}

      result = Lens.over(data, lens, fn _v -> raise ArgumentError, "bad arg" end, as: :tuple)
      assert {:error, %ArgumentError{message: "bad arg"}} = result
    end

    test "over!/3 propagates exceptions from user function" do
      lens = Lens.key(:value)
      data = %{value: 10}

      assert_raise RuntimeError, "user error", fn ->
        Lens.over!(data, lens, fn _v -> raise "user error" end)
      end
    end

    test "over/4 with :raise mode propagates exceptions from user function" do
      lens = Lens.key(:value)
      data = %{value: 10}

      assert_raise ArithmeticError, fn ->
        Lens.over(data, lens, fn v -> v / 0 end, as: :raise)
      end
    end

    test "over/4 catches exceptions in composed lenses" do
      lens = Lens.path([:a, :b, :c])
      data = %{a: %{b: %{c: 5}}}

      result = Lens.over(data, lens, fn _v -> raise "nested error" end)
      assert %Funx.Monad.Either.Left{left: %RuntimeError{}} = result
    end
  end

  # ============================================================================
  # Edge Cases and Special Values
  # ============================================================================

  describe "nil value handling" do
    test "viewing a field that contains nil" do
      lens = Lens.key(:value)
      data = %{value: nil, other: "data"}

      assert Lens.view!(data, lens) == nil
    end

    test "setting a field to nil" do
      lens = Lens.key(:age)
      data = %{age: 30, name: "Alice"}

      result = Lens.set!(data, lens, nil)
      assert result == %{age: nil, name: "Alice"}
    end

    test "over!/3 with nil value" do
      lens = Lens.key(:value)
      data = %{value: nil}

      # Function receives nil and can handle it
      result = Lens.over!(data, lens, fn v -> v || "default" end)
      assert result == %{value: "default"}
    end

    test "nested path with nil intermediate value" do
      lens = Lens.key(:data)
      data = %{data: nil}

      # Viewing nil is fine
      assert Lens.view!(data, lens) == nil

      # Setting nil is fine
      result = Lens.set!(data, lens, %{inner: "value"})
      assert result == %{data: %{inner: "value"}}
    end

    test "struct field set to nil preserves struct type" do
      lens = Lens.key(:name)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      result = Lens.set!(user, lens, nil)
      assert result.__struct__ == User
      assert result.name == nil
      assert result.age == 30
    end
  end

  describe "string keys" do
    test "key/1 works with string keys on maps" do
      lens = Lens.key("count")
      data = %{"count" => 5, "name" => "test"}

      assert Lens.view!(data, lens) == 5

      result = Lens.set!(data, lens, 10)
      assert result == %{"count" => 10, "name" => "test"}
    end

    test "path/1 works with mixed string and atom keys" do
      lens = Lens.path(["user", :name])
      data = %{"user" => %{name: "Alice", age: 30}}

      assert Lens.view!(data, lens) == "Alice"

      result = Lens.set!(data, lens, "Bob")
      assert result == %{"user" => %{name: "Bob", age: 30}}
    end

    test "compose with string and atom key lenses" do
      outer = Lens.key("profile")
      inner = Lens.key(:score)
      lens = Lens.compose(outer, inner)

      data = %{"profile" => %{score: 100, level: 5}}

      assert Lens.view!(data, lens) == 100

      result = Lens.set!(data, lens, 200)
      assert result == %{"profile" => %{score: 200, level: 5}}
    end

    test "string key on missing key raises KeyError" do
      lens = Lens.key("missing")

      assert_raise KeyError, fn ->
        Lens.view!(%{}, lens)
      end

      assert_raise KeyError, fn ->
        Lens.set!(%{}, lens, "value")
      end
    end
  end

  describe "composition extremes" do
    test "very deep nesting (10+ levels)" do
      # Build a 12-level deep structure
      data =
        %{
          l1: %{
            l2: %{l3: %{l4: %{l5: %{l6: %{l7: %{l8: %{l9: %{l10: %{l11: %{l12: "deep"}}}}}}}}}}
          }
        }

      lens =
        Lens.compose([
          Lens.key(:l1),
          Lens.key(:l2),
          Lens.key(:l3),
          Lens.key(:l4),
          Lens.key(:l5),
          Lens.key(:l6),
          Lens.key(:l7),
          Lens.key(:l8),
          Lens.key(:l9),
          Lens.key(:l10),
          Lens.key(:l11),
          Lens.key(:l12)
        ])

      assert Lens.view!(data, lens) == "deep"

      result = Lens.set!(data, lens, "very deep")

      assert get_in(result, [:l1, :l2, :l3, :l4, :l5, :l6, :l7, :l8, :l9, :l10, :l11, :l12]) ==
               "very deep"
    end

    test "composing many identity lenses has no effect" do
      import Funx.Monoid
      alias Funx.Monoid.Optics.LensCompose

      id = empty(%LensCompose{})

      # Compose 5 identity lenses
      many_ids =
        [id, id, id, id, id]
        |> Enum.reduce(fn lens, acc -> append(acc, lens) end)
        |> LensCompose.unwrap()

      data = %{x: 1, y: 2}

      assert Lens.view!(data, many_ids) == data
      assert Lens.set!(data, many_ids, %{x: 10, y: 20}) == %{x: 10, y: 20}
    end

    test "composing same lens multiple times" do
      # This doesn't make practical sense but should work
      key_lens = Lens.key(:nested)

      # Create a structure where the same key exists at multiple levels
      data = %{nested: %{nested: %{nested: "value"}}}

      lens = Lens.compose(Lens.compose(key_lens, key_lens), key_lens)

      assert Lens.view!(data, lens) == "value"

      result = Lens.set!(data, lens, "updated")
      assert result.nested.nested.nested == "updated"
    end
  end

  describe "reference equality and performance" do
    test "setting to the same value creates equal structure" do
      lens = Lens.key(:name)
      data = %{name: "Alice", age: 30}

      current = Lens.view!(data, lens)
      result = Lens.set!(data, lens, current)

      # Should be equal (though not necessarily the same reference in Elixir)
      assert result == data
    end

    test "setting to same value in struct preserves equality" do
      lens = Lens.key(:age)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      current = Lens.view!(user, lens)
      result = Lens.set!(user, lens, current)

      assert result == user
      assert result.__struct__ == User
    end

    test "nested set with same value preserves structure" do
      lens = Lens.path([:a, :b, :c])
      data = %{a: %{b: %{c: "value", d: "other"}}}

      current = Lens.view!(data, lens)
      result = Lens.set!(data, lens, current)

      assert result == data
    end
  end

  # ============================================================================
  # Custom Lenses Tests
  # ============================================================================

  describe "custom lenses" do
    test "custom lens for first element of tuple" do
      lens =
        Lens.make(
          fn {first, _second} -> first end,
          fn {_first, second}, new_first -> {new_first, second} end
        )

      data = {"hello", "world"}

      assert Lens.view!(data, lens) == "hello"

      result = Lens.set!(data, lens, "goodbye")
      assert result == {"goodbye", "world"}
    end

    test "custom lens for list head" do
      lens =
        Lens.make(
          fn [head | _tail] -> head end,
          fn [_head | tail], new_head -> [new_head | tail] end
        )

      data = [1, 2, 3, 4]

      assert Lens.view!(data, lens) == 1

      result = Lens.set!(data, lens, 10)
      assert result == [10, 2, 3, 4]
    end

    test "custom lens composition" do
      first_elem =
        Lens.make(
          fn {first, _} -> first end,
          fn {_, second}, new_first -> {new_first, second} end
        )

      key_lens = Lens.key(:value)
      composed = Lens.compose(first_elem, key_lens)

      data = {%{value: 42}, %{other: "data"}}

      assert Lens.view!(data, composed) == 42

      result = Lens.set!(data, composed, 100)
      assert result == {%{value: 100}, %{other: "data"}}
    end

    test "custom lens with over!/3" do
      lens =
        Lens.make(
          fn %{count: c} -> c end,
          fn m, new_count -> %{m | count: new_count} end
        )

      data = %{count: 5, other: "field"}

      result = Lens.over!(data, lens, fn c -> c * 2 end)
      assert result == %{count: 10, other: "field"}
    end
  end

  # ============================================================================
  # Lens Laws Verification
  # ============================================================================

  describe "lens laws verification" do
    test "get-put law: set(s, lens, view(s, lens)) == s" do
      lens = Lens.key(:age)
      data = %{age: 30, name: "Alice"}

      # Setting to the current value should return equivalent structure
      current = Lens.view!(data, lens)
      result = Lens.set!(data, lens, current)

      assert result == data
    end

    test "get-put law with nested lens" do
      lens = Lens.path([:user, :profile, :score])
      data = %{user: %{profile: %{score: 100, level: 5}}}

      current = Lens.view!(data, lens)
      result = Lens.set!(data, lens, current)

      assert result == data
    end

    test "get-put law with struct" do
      lens = Lens.key(:name)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      current = Lens.view!(user, lens)
      result = Lens.set!(user, lens, current)

      assert result == user
      assert result.__struct__ == User
    end

    test "put-get law: view(set(s, lens, a), lens) == a" do
      lens = Lens.key(:count)
      data = %{count: 5}
      new_value = 10

      updated = Lens.set!(data, lens, new_value)
      retrieved = Lens.view!(updated, lens)

      assert retrieved == new_value
    end

    test "put-get law with nested lens" do
      lens = Lens.path([:stats, :wins])
      data = %{stats: %{wins: 3, losses: 2}}
      new_value = 7

      updated = Lens.set!(data, lens, new_value)
      retrieved = Lens.view!(updated, lens)

      assert retrieved == new_value
    end

    test "put-get law with struct" do
      lens = Lens.key(:age)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      new_age = 31

      updated = Lens.set!(user, lens, new_age)
      retrieved = Lens.view!(updated, lens)

      assert retrieved == new_age
    end

    test "put-put law: set(set(s, lens, a), lens, b) == set(s, lens, b)" do
      lens = Lens.key(:value)
      data = %{value: 1}

      # Setting twice should only keep the last value
      result1 = data |> Lens.set!(lens, 10) |> Lens.set!(lens, 20)
      result2 = data |> Lens.set!(lens, 20)

      assert result1 == result2
    end

    test "put-put law with nested lens" do
      lens = Lens.path([:a, :b])
      data = %{a: %{b: "original"}}

      result1 = data |> Lens.set!(lens, "first") |> Lens.set!(lens, "second")
      result2 = data |> Lens.set!(lens, "second")

      assert result1 == result2
    end

    test "put-put law with struct" do
      lens = Lens.key(:email)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}

      result1 =
        user |> Lens.set!(lens, "bob@example.com") |> Lens.set!(lens, "charlie@example.com")

      result2 = user |> Lens.set!(lens, "charlie@example.com")

      assert result1 == result2
      assert result1.__struct__ == User
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: lens laws" do
    property "get-put law: set(s, lens, view(s, lens)) == s for maps" do
      check all(
              name <- string(:alphanumeric),
              age <- integer(1..150),
              score <- integer(0..1000)
            ) do
        data = %{name: name, age: age, score: score}
        lens = Lens.key(:age)

        # Setting to the current value should return the same structure
        current = Lens.view!(data, lens)
        result = Lens.set!(data, lens, current)

        assert result == data
      end
    end

    property "get-put law: set(s, lens, view(s, lens)) == s for nested paths" do
      check all(
              name <- string(:alphanumeric),
              wins <- integer(0..1000),
              losses <- integer(0..1000)
            ) do
        data = %{
          player: %{
            name: name,
            stats: %{wins: wins, losses: losses}
          }
        }

        lens = Lens.path([:player, :stats, :wins])

        current = Lens.view!(data, lens)
        result = Lens.set!(data, lens, current)

        assert result == data
      end
    end

    property "get-put law: set(s, lens, view(s, lens)) == s for structs" do
      check all(
              name <- string(:alphanumeric),
              age <- integer(1..150),
              email <- string(:alphanumeric)
            ) do
        user = %User{name: name, age: age, email: email}
        lens = Lens.key(:age)

        current = Lens.view!(user, lens)
        result = Lens.set!(user, lens, current)

        assert result == user
        assert result.__struct__ == User
      end
    end

    property "put-get law: view(set(s, lens, a), lens) == a for maps" do
      check all(
              initial_age <- integer(1..150),
              new_age <- integer(1..150),
              name <- string(:alphanumeric)
            ) do
        data = %{name: name, age: initial_age}
        lens = Lens.key(:age)

        updated = Lens.set!(data, lens, new_age)
        retrieved = Lens.view!(updated, lens)

        assert retrieved == new_age
      end
    end

    property "put-get law: view(set(s, lens, a), lens) == a for nested paths" do
      check all(
              initial_wins <- integer(0..1000),
              new_wins <- integer(0..1000),
              losses <- integer(0..1000)
            ) do
        data = %{stats: %{wins: initial_wins, losses: losses}}
        lens = Lens.path([:stats, :wins])

        updated = Lens.set!(data, lens, new_wins)
        retrieved = Lens.view!(updated, lens)

        assert retrieved == new_wins
      end
    end

    property "put-get law: view(set(s, lens, a), lens) == a for structs" do
      check all(
              initial_age <- integer(1..150),
              new_age <- integer(1..150),
              name <- string(:alphanumeric),
              email <- string(:alphanumeric)
            ) do
        user = %User{name: name, age: initial_age, email: email}
        lens = Lens.key(:age)

        updated = Lens.set!(user, lens, new_age)
        retrieved = Lens.view!(updated, lens)

        assert retrieved == new_age
        assert updated.__struct__ == User
      end
    end

    property "put-put law: set(set(s, lens, a), lens, b) == set(s, lens, b) for maps" do
      check all(
              initial <- integer(0..1000),
              first_value <- integer(0..1000),
              second_value <- integer(0..1000)
            ) do
        data = %{value: initial, other: "data"}
        lens = Lens.key(:value)

        # Setting twice should only keep the last value
        result1 = data |> Lens.set!(lens, first_value) |> Lens.set!(lens, second_value)
        result2 = data |> Lens.set!(lens, second_value)

        assert result1 == result2
      end
    end

    property "put-put law: set(set(s, lens, a), lens, b) == set(s, lens, b) for nested paths" do
      check all(
              initial <- string(:alphanumeric),
              first <- string(:alphanumeric),
              second <- string(:alphanumeric)
            ) do
        data = %{a: %{b: initial, c: "other"}}
        lens = Lens.path([:a, :b])

        result1 = data |> Lens.set!(lens, first) |> Lens.set!(lens, second)
        result2 = data |> Lens.set!(lens, second)

        assert result1 == result2
      end
    end

    property "put-put law: set(set(s, lens, a), lens, b) == set(s, lens, b) for structs" do
      check all(
              initial_email <- string(:alphanumeric),
              first_email <- string(:alphanumeric),
              second_email <- string(:alphanumeric),
              name <- string(:alphanumeric),
              age <- integer(1..150)
            ) do
        user = %User{name: name, age: age, email: initial_email}
        lens = Lens.key(:email)

        result1 = user |> Lens.set!(lens, first_email) |> Lens.set!(lens, second_email)
        result2 = user |> Lens.set!(lens, second_email)

        assert result1 == result2
        assert result1.__struct__ == User
      end
    end

    property "lens composition preserves get-put law" do
      check all(
              name <- string(:alphanumeric),
              score <- integer(0..1000),
              level <- integer(1..100)
            ) do
        data = %{user: %{profile: %{score: score, level: level}}, name: name}

        outer = Lens.key(:user)
        inner = Lens.key(:profile)
        innermost = Lens.key(:score)
        lens = Lens.compose(Lens.compose(outer, inner), innermost)

        current = Lens.view!(data, lens)
        result = Lens.set!(data, lens, current)

        assert result == data
      end
    end

    property "over! preserves lens laws (view after over with identity)" do
      check all(
              age <- integer(1..150),
              name <- string(:alphanumeric)
            ) do
        data = %{name: name, age: age}
        lens = Lens.key(:age)

        # Applying identity function via over! should not change the structure
        result = Lens.over!(data, lens, fn x -> x end)

        assert result == data
      end
    end

    property "over! with function composition" do
      check all(
              initial <- integer(0..100),
              add_amount <- integer(1..50),
              multiply_by <- integer(1..10)
            ) do
        data = %{value: initial}
        lens = Lens.key(:value)

        # Composing operations via over!
        result1 =
          data
          |> Lens.over!(lens, fn x -> x + add_amount end)
          |> Lens.over!(lens, fn x -> x * multiply_by end)

        result2 = Lens.over!(data, lens, fn x -> (x + add_amount) * multiply_by end)

        assert result1 == result2
      end
    end
  end
end
