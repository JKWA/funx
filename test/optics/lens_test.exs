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
    result = %{count: 3} |> Lens.set!(10, lens)
    assert result == %{count: 10}
  end

  test "compose/2 focuses through nested structures" do
    outer = Lens.key(:profile)
    inner = Lens.key(:score)
    lens = Lens.compose(outer, inner)

    data = %{profile: %{score: 5}}

    assert data |> Lens.view!(lens) == 5

    updated = data |> Lens.set!(9, lens)
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
      |> Lens.set!(4, lens)

    assert updated == %{stats: %{losses: 4}}
  end

  test "compose/2 behaves identically to nested path when structure matches" do
    a = Lens.key(:outer)
    b = Lens.key(:inner)
    composed = Lens.compose(a, b)

    path_lens = Lens.path([:outer, :inner])

    data = %{outer: %{inner: 7}}

    assert data |> Lens.view!(composed) == data |> Lens.view!(path_lens)

    updated1 = data |> Lens.set!(9, composed)
    updated2 = data |> Lens.set!(9, path_lens)

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
      updated = Lens.set!(user, "Bob", lens)

      assert updated == %User{name: "Bob", age: 30, email: "alice@example.com"}
      assert updated.__struct__ == User
    end

    test "key/1 preserves other struct fields when updating" do
      lens = Lens.key(:age)
      user = %User{name: "Alice", age: 30, email: "alice@example.com"}
      updated = Lens.set!(user, 31, lens)

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

      updated = Lens.set!(profile, "Bob", lens)
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

      updated = Lens.set!(profile, "bob@example.com", lens)

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
      updated = Lens.set!(employee, "SF", lens)

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

      updated = Lens.set!(employee, "789 Pine St", lens)

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

      updated = Lens.set!(profile_with_meta, "David", lens)

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

      updated = Lens.set!(user, "Frank", lens)
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
        |> Lens.set!("Hannah", name_lens)
        |> Lens.set!(41, age_lens)
        |> Lens.set!("hannah@example.com", email_lens)

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

      updated = Lens.set!(employee, "02102", zip_lens)

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

      updated = Lens.set!(data, 99, composed)
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
      assert Lens.set!(data, "Bob", left) == %{name: "Bob", age: 30}

      # Right identity: append(l, id) == l
      right = append(l, id) |> LensCompose.unwrap()
      assert Lens.view!(data, right) == "Alice"
      assert Lens.set!(data, "Bob", right) == %{name: "Bob", age: 30}
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
      updated_left = Lens.set!(data, "SF", left_assoc)
      updated_right = Lens.set!(data, "SF", right_assoc)
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

      updated = Lens.set!(data, 26, composed)
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
      assert Lens.set!(data, new_data, identity) == new_data
    end

    test "concat with single lens returns that lens" do
      l = Lens.key(:name)
      composed = Lens.concat([l])

      data = %{name: "Alice", age: 30}

      assert Lens.view!(data, composed) == "Alice"
      assert Lens.set!(data, "Bob", composed) == %{name: "Bob", age: 30}
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

      updated = Lens.set!(profile, "Bob", composed)
      assert updated.user.name == "Bob"
      assert updated.__struct__ == Profile
      assert updated.user.__struct__ == User
    end
  end
end
