defmodule Funx.Optics.LensTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest Funx.Optics.Lens

  alias Funx.Optics.Lens

  defmodule User do
    defstruct [:name, :age, :email]
  end

  defmodule Profile do
    defstruct [:user, :score]
  end

  defmodule Address do
    defstruct [:street, :city, :zip]
  end

  defmodule Company do
    defstruct [:name, :address]
  end

  defmodule Employee do
    defstruct [:user, :company, :salary]
  end

  test "get/2 retrieves the focused value" do
    lens = Lens.key(:name)
    assert %{name: "Alice"} |> Lens.view!(lens) == "Alice"
  end

  test "set/3 replaces the focused value" do
    lens = Lens.key(:count)
    result = %{count: 3} |> Lens.set!(lens, 10)
    assert result == %{count: 10}
  end

  test "compose/2 focuses through nested structures" do
    outer = Lens.key(:profile)
    inner = Lens.key(:score)
    lens = Lens.compose(outer, inner)

    data = %{profile: %{score: 5}}

    assert data |> Lens.view!(lens) == 5

    updated = data |> Lens.set!(lens, 9)
    assert updated == %{profile: %{score: 9}}
  end

  test "path/1 gets nested values" do
    lens = Lens.path([:stats, :wins])
    assert %{stats: %{wins: 2}} |> Lens.view!(lens) == 2
  end

  test "path/1 sets nested values" do
    lens = Lens.path([:stats, :losses])

    updated =
      %{stats: %{losses: 1}}
      |> Lens.set!(lens, 4)

    assert updated == %{stats: %{losses: 4}}
  end

  test "compose/2 behaves identically to nested path when structure matches" do
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

    test "concat/1 composes multiple lenses through nested structs" do
      lenses = [
        Lens.key(:company),
        Lens.key(:address),
        Lens.key(:city)
      ]

      lens = Lens.concat(lenses)

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

    test "compose/2 can be chained multiple times with structs" do
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

    test "deeply nested struct composition with concat" do
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
      zip_lens = Lens.concat([Lens.key(:company), Lens.key(:address), Lens.key(:zip)])

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
  end

  describe "Monoid structure via LensCompose" do
    alias Funx.Monoid.LensCompose

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

    test "concat composes multiple lenses" do
      lenses = [
        Lens.key(:user),
        Lens.key(:profile),
        Lens.key(:age)
      ]

      composed = Lens.concat(lenses)

      data = %{user: %{profile: %{age: 25, name: "Alice"}}}

      assert Lens.view!(data, composed) == 25

      updated = Lens.set!(data, composed, 26)
      assert updated.user.profile.age == 26
      assert updated.user.profile.name == "Alice"
    end

    test "concat with empty list returns identity lens" do
      identity = Lens.concat([])

      data = %{name: "Alice", age: 30}

      # Identity lens views the whole structure
      assert Lens.view!(data, identity) == data

      # Identity lens replaces the whole structure
      new_data = %{name: "Bob", age: 25}
      assert Lens.set!(data, identity, new_data) == new_data
    end

    test "concat with single lens returns that lens" do
      l = Lens.key(:name)
      composed = Lens.concat([l])

      data = %{name: "Alice", age: 30}

      assert Lens.view!(data, composed) == "Alice"
      assert Lens.set!(data, composed, "Bob") == %{name: "Bob", age: 30}
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

    test "preserves struct type when updating a struct field" do
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

    test "works through nested structs with compose/2" do
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

    test "deeply nested struct update with concat/1" do
      lens =
        Lens.concat([
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

  describe "safe view/3" do
    test "returns Right on success with default :either mode" do
      lens = Lens.key(:name)
      result = Lens.view(%{name: "Alice"}, lens)

      assert %Funx.Monad.Either.Right{right: "Alice"} = result
    end

    test "returns Left on error with default :either mode" do
      lens = Lens.key(:name)
      result = Lens.view(%{}, lens)

      assert %Funx.Monad.Either.Left{left: %KeyError{}} = result
    end

    test "returns Right on success with explicit :either mode" do
      lens = Lens.key(:age)
      result = Lens.view(%{age: 30}, lens, as: :either)

      assert %Funx.Monad.Either.Right{right: 30} = result
    end

    test "returns {:ok, value} on success with :tuple mode" do
      lens = Lens.key(:name)
      result = Lens.view(%{name: "Bob"}, lens, as: :tuple)

      assert {:ok, "Bob"} = result
    end

    test "returns {:error, exception} on error with :tuple mode" do
      lens = Lens.key(:name)
      result = Lens.view(%{}, lens, as: :tuple)

      assert {:error, %KeyError{key: :name}} = result
    end

    test "raises on error with :raise mode" do
      lens = Lens.key(:name)

      assert_raise KeyError, fn ->
        Lens.view(%{}, lens, as: :raise)
      end
    end

    test "returns value directly on success with :raise mode" do
      lens = Lens.key(:name)
      result = Lens.view(%{name: "Charlie"}, lens, as: :raise)

      assert result == "Charlie"
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
    test "returns Right on success with default :either mode" do
      lens = Lens.key(:age)
      result = Lens.set(%{age: 30}, lens, 31)

      assert %Funx.Monad.Either.Right{right: %{age: 31}} = result
    end

    test "returns Left on error with default :either mode" do
      lens = Lens.key(:age)
      result = Lens.set(%{}, lens, 31)

      assert %Funx.Monad.Either.Left{left: %KeyError{}} = result
    end

    test "returns Right on success with explicit :either mode" do
      lens = Lens.key(:name)
      result = Lens.set(%{name: "Alice"}, lens, "Bob", as: :either)

      assert %Funx.Monad.Either.Right{right: %{name: "Bob"}} = result
    end

    test "returns {:ok, updated} on success with :tuple mode" do
      lens = Lens.key(:count)
      result = Lens.set(%{count: 5}, lens, 10, as: :tuple)

      assert {:ok, %{count: 10}} = result
    end

    test "returns {:error, exception} on error with :tuple mode" do
      lens = Lens.key(:count)
      result = Lens.set(%{}, lens, 10, as: :tuple)

      assert {:error, %KeyError{key: :count}} = result
    end

    test "raises on error with :raise mode" do
      lens = Lens.key(:name)

      assert_raise KeyError, fn ->
        Lens.set(%{}, lens, "Alice", as: :raise)
      end
    end

    test "returns value directly on success with :raise mode" do
      lens = Lens.key(:name)
      result = Lens.set(%{name: "Alice"}, lens, "Bob", as: :raise)

      assert result == %{name: "Bob"}
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
    test "returns Right on success with default :either mode" do
      lens = Lens.key(:age)
      result = Lens.over(%{age: 30}, lens, fn a -> a + 1 end)

      assert %Funx.Monad.Either.Right{right: %{age: 31}} = result
    end

    test "returns Left on error with default :either mode" do
      lens = Lens.key(:age)
      result = Lens.over(%{}, lens, fn a -> a + 1 end)

      assert %Funx.Monad.Either.Left{left: %KeyError{}} = result
    end

    test "returns Right on success with explicit :either mode" do
      lens = Lens.key(:count)
      result = Lens.over(%{count: 5}, lens, fn c -> c * 2 end, as: :either)

      assert %Funx.Monad.Either.Right{right: %{count: 10}} = result
    end

    test "returns {:ok, updated} on success with :tuple mode" do
      lens = Lens.key(:score)
      result = Lens.over(%{score: 10}, lens, fn s -> s + 5 end, as: :tuple)

      assert {:ok, %{score: 15}} = result
    end

    test "returns {:error, exception} on error with :tuple mode" do
      lens = Lens.key(:score)
      result = Lens.over(%{}, lens, fn s -> s + 5 end, as: :tuple)

      assert {:error, %KeyError{key: :score}} = result
    end

    test "raises on error with :raise mode" do
      lens = Lens.key(:value)

      assert_raise KeyError, fn ->
        Lens.over(%{}, lens, fn v -> v + 1 end, as: :raise)
      end
    end

    test "returns value directly on success with :raise mode" do
      lens = Lens.key(:value)
      result = Lens.over(%{value: 10}, lens, fn v -> v * 2 end, as: :raise)

      assert result == %{value: 20}
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
end
