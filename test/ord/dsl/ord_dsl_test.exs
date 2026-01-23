defmodule Funx.Ord.Dsl.OrdDslTest do
  @moduledoc false
  # Comprehensive test suite for the Ord DSL
  #
  # Test Organization:
  #   - Basic atom projections (asc/desc on fields)
  #   - Atom with or_else (handling nil values)
  #   - Function projections (anonymous and captured)
  #   - Helper function projections (reusable Lens/Prism helpers)
  #   - Explicit Lens projections
  #   - Explicit Prism projections
  #   - Bare Prism with Maybe.lift_ord
  #   - Behaviour module projections
  #   - Protocol dispatch
  #   - Complex compositions
  #   - Compile-time error handling
  #   - Runtime error handling
  #   - Edge cases
  #   - Bare struct module type filtering
  #   - Ord variable projections (composing and reusing orderings)
  #   - Property-based law verification

  use ExUnit.Case, async: true
  use ExUnitProperties
  use Funx.Ord

  alias Funx.Optics.{Lens, Prism}
  alias Funx.Ord

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule Person do
    defstruct [:name, :age, :score, :address, :bio]
  end

  defmodule Address do
    defstruct [:street, :city, :state, :zip]
  end

  defmodule Check do
    defstruct [:name, :routing_number, :account_number, :amount]
  end

  defmodule CreditCard do
    defstruct [:name, :number, :expiry, :amount]
  end

  defmodule LimitedStruct do
    defstruct [:name]
  end

  defmodule NullableStruct do
    defstruct [:name, :optional_field]
  end

  defmodule Container do
    defstruct [:value]
  end

  defmodule Company do
    defstruct [:name, :address]
  end

  defmodule Employee do
    defstruct [:name, :company]
  end

  defmodule CompanyNoAddress do
    defstruct [:name]
  end

  defmodule Country do
    defstruct [:name, :code]
  end

  defmodule Region do
    defstruct [:name, :country]
  end

  defmodule City do
    defstruct [:name, :region]
  end

  defmodule Office do
    defstruct [:name, :city]
  end

  defmodule Department do
    defstruct [:name, :office]
  end

  # Struct for testing explicit protocol tiebreaker
  defmodule Worker do
    defstruct [:department, :name, :worker_id]
  end

  # ============================================================================
  # Protocol Implementations
  # ============================================================================

  # Worker orders by worker_id (natural ordering for the struct)
  defimpl Funx.Ord.Protocol, for: Worker do
    def lt?(a, b), do: a.worker_id < b.worker_id
    def le?(a, b), do: a.worker_id <= b.worker_id
    def gt?(a, b), do: a.worker_id > b.worker_id
    def ge?(a, b), do: a.worker_id >= b.worker_id
  end

  defimpl Funx.Ord.Protocol, for: Address do
    def lt?(a, b), do: {a.state, a.city} < {b.state, b.city}
    def le?(a, b), do: {a.state, a.city} <= {b.state, b.city}
    def gt?(a, b), do: {a.state, a.city} > {b.state, b.city}
    def ge?(a, b), do: {a.state, a.city} >= {b.state, b.city}
  end

  # ============================================================================
  # Module with Ord Protocol Functions
  # ============================================================================

  defmodule ReverseStringOrd do
    # Module with Ord protocol functions for testing :module_ord type
    def lt?(a, b), do: String.reverse(a) < String.reverse(b)
    def le?(a, b), do: String.reverse(a) <= String.reverse(b)
    def gt?(a, b), do: String.reverse(a) > String.reverse(b)
    def ge?(a, b), do: String.reverse(a) >= String.reverse(b)
  end

  # ============================================================================
  # Custom Behaviour Projections
  # ============================================================================

  defmodule NameLength do
    @behaviour Funx.Ord.Dsl.Behaviour

    alias Funx.Ord

    @impl true
    def ord(_opts) do
      Ord.contramap(&String.length(&1.name))
    end
  end

  defmodule WeightedScore do
    @behaviour Funx.Ord.Dsl.Behaviour

    alias Funx.Ord

    @impl true
    def ord(opts) do
      weight = Keyword.get(opts, :weight, 1.0)
      Ord.contramap(fn person -> (person.score || 0) * weight end)
    end
  end

  defmodule OptionalBio do
    @behaviour Funx.Ord.Dsl.Behaviour

    alias Funx.Ord

    @impl true
    def ord(_opts) do
      # Returns nil for people without bio
      Ord.contramap(& &1.bio)
    end
  end

  # ============================================================================
  # Projection Helper Functions
  # ============================================================================

  defmodule ProjectionHelpers do
    @moduledoc false
    # Reusable projection functions for testing helper function syntax

    alias Funx.Optics.{Lens, Prism}

    def name_lens, do: Lens.key(:name)
    def age_lens, do: Lens.key(:age)
    def score_prism, do: Prism.key(:score)
    def score_with_or_else, do: {Prism.key(:score), 0}
  end

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp fixture(:alice) do
    %Person{name: "Alice", age: 30, score: 100, bio: "Software engineer"}
  end

  defp fixture(:bob) do
    %Person{name: "Bob", age: 25, score: 50, bio: "Developer"}
  end

  defp fixture(:charlie) do
    %Person{name: "Charlie", age: 30, score: nil, bio: "Designer"}
  end

  defp fixture(:alice_with_address) do
    %Person{
      name: "Alice",
      age: 30,
      address: %Address{city: "Austin", state: "TX", street: "Main St", zip: "78701"}
    }
  end

  defp fixture(:bob_with_address) do
    %Person{
      name: "Bob",
      age: 25,
      address: %Address{city: "Boston", state: "MA", street: "Oak Ave", zip: "02101"}
    }
  end

  defp fixture(:charlie_with_address) do
    %Person{
      name: "Charlie",
      age: 35,
      address: %Address{city: "Houston", state: "TX", street: "Pine Rd", zip: "77001"}
    }
  end

  # ============================================================================
  # Basic Atom Projection Tests
  # ============================================================================

  describe "basic atom projections" do
    test "asc sorts in ascending order" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_name =
        ord do
          asc :name
        end

      assert Ord.compare(alice, bob, ord_name) == :lt
      assert Ord.compare(bob, alice, ord_name) == :gt
    end

    test "desc sorts in descending order" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_name_desc =
        ord do
          desc :name
        end

      assert Ord.compare(alice, bob, ord_name_desc) == :gt
      assert Ord.compare(bob, alice, ord_name_desc) == :lt
    end

    test "multiple fields use tie-breaking" do
      alice_30 = %Person{name: "Alice", age: 30}
      alice_25 = %Person{name: "Alice", age: 25}
      bob_30 = %Person{name: "Bob", age: 30}

      ord_name_then_age =
        ord do
          asc :name
          asc :age
        end

      assert Ord.compare(alice_25, alice_30, ord_name_then_age) == :lt
      assert Ord.compare(alice_30, bob_30, ord_name_then_age) == :lt
    end

    test "mixed asc and desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_desc_age_asc_name =
        ord do
          desc :age
          asc :name
        end

      # Alice age=30 > Bob age=25, so Alice comes first (desc)
      assert Ord.compare(alice, bob, ord_desc_age_asc_name) == :lt
    end
  end

  # ============================================================================
  # Atom with or_else (Prism) Tests
  # ============================================================================

  describe "atom with or_else (Prism)" do
    test "nil value uses or_else" do
      with_score = %Person{name: "Alice", score: 100}
      without_score = %Person{name: "Bob", score: nil}

      ord_score =
        ord do
          asc :score, or_else: 0
        end

      assert Ord.compare(without_score, with_score, ord_score) == :lt
    end

    test "combines with other projections" do
      alice_no_score = %Person{name: "Alice", age: 30, score: nil}
      bob_with_score = %Person{name: "Bob", age: 25, score: 50}

      ord_score_then_age =
        ord do
          asc :score, or_else: 0
          desc :age
        end

      assert Ord.compare(alice_no_score, bob_with_score, ord_score_then_age) == :lt
    end

    test "or_else with nil value treats nil as comparable value" do
      person_with_score = %Person{name: "Alice", score: 100}
      person_without_score = %Person{name: "Bob", score: nil}

      ord_score_nil_fallback =
        ord do
          asc :score, or_else: nil
        end

      # When score is nil, or_else provides nil as the fallback value
      # Then compares nil (fallback) vs 100 (actual value)
      # nil < 100 in standard ordering
      assert Ord.compare(person_without_score, person_with_score, ord_score_nil_fallback) == :lt
    end
  end

  # ============================================================================
  # List Path Tests
  # ============================================================================

  describe "list paths (nested field access)" do
    test "list path without or_else" do
      nested1 = %{user: %{profile: %{age: 25}}}
      nested2 = %{user: %{profile: %{age: 30}}}

      ord_age =
        ord do
          asc [:user, :profile, :age]
        end

      assert Ord.compare(nested1, nested2, ord_age) == :lt
      assert Ord.compare(nested2, nested1, ord_age) == :gt
    end

    test "list path with or_else" do
      complete = %{user: %{profile: %{score: 100}}}
      incomplete = %{user: %{}}

      ord_score =
        ord do
          asc [:user, :profile, :score], or_else: 0
        end

      # Incomplete gets default of 0, complete has 100
      assert Ord.compare(incomplete, complete, ord_score) == :lt
    end

    test "list path with struct" do
      person1 = %Person{name: "Alice", address: %Address{city: "Boston"}}
      person2 = %Person{name: "Bob", address: %Address{city: "Austin"}}

      ord_city =
        ord do
          asc [Person, :address, Address, :city]
        end

      assert Ord.compare(person2, person1, ord_city) == :lt
      assert Ord.compare(person1, person2, ord_city) == :gt
    end

    test "list path with desc" do
      nested1 = %{user: %{profile: %{age: 25}}}
      nested2 = %{user: %{profile: %{age: 30}}}

      ord_age_desc =
        ord do
          desc [:user, :profile, :age]
        end

      # Reversed order from asc
      assert Ord.compare(nested1, nested2, ord_age_desc) == :gt
      assert Ord.compare(nested2, nested1, ord_age_desc) == :lt
    end

    test "multiple list paths" do
      data1 = %{user: %{name: "Alice", age: 25}}
      data2 = %{user: %{name: "Alice", age: 30}}
      data3 = %{user: %{name: "Bob", age: 20}}

      ord_user =
        ord do
          asc [:user, :name]
          asc [:user, :age]
        end

      # Same name, different age
      assert Ord.compare(data1, data2, ord_user) == :lt
      # Different name
      assert Ord.compare(data2, data3, ord_user) == :lt
    end
  end

  # ============================================================================
  # Function Projection Tests
  # ============================================================================

  describe "function projections" do
    test "anonymous function with asc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_bio_length =
        ord do
          asc &String.length(&1.bio)
        end

      assert Ord.compare(bob, alice, ord_bio_length) == :lt
    end

    test "captured function" do
      items = ["apple", "kiwi", "banana"]

      ord_length =
        ord do
          asc &String.length/1
        end

      sorted = Enum.sort(items, Ord.comparator(ord_length))
      assert sorted == ["kiwi", "apple", "banana"]
    end

    test "anonymous function with desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_bio_length_desc =
        ord do
          desc &String.length(&1.bio)
        end

      assert Ord.compare(alice, bob, ord_bio_length_desc) == :lt
    end
  end

  # ============================================================================
  # Remote Function Call Tests
  # ============================================================================

  describe "reusable projections via helper functions" do
    test "0-arity function returning Lens" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name =
        ord do
          asc ProjectionHelpers.name_lens()
        end

      assert Ord.compare(alice, bob, ord_by_name) == :lt
    end

    test "0-arity function returning Lens with desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name_desc =
        ord do
          desc ProjectionHelpers.name_lens()
        end

      # Reversed: Alice > Bob in desc
      assert Ord.compare(alice, bob, ord_by_name_desc) == :gt
    end

    test "0-arity function returning bare Prism" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score =
        ord do
          asc ProjectionHelpers.score_prism()
        end

      # Nothing < Just with bare Prism
      assert Ord.compare(charlie, alice, ord_score) == :lt
    end

    test "0-arity function returning Prism tuple with or_else" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_with_or_else =
        ord do
          asc ProjectionHelpers.score_with_or_else()
        end

      # nil treated as 0, so 0 < 100
      assert Ord.compare(charlie, alice, ord_with_or_else) == :lt
    end

    test "0-arity function with or_else option (syntactic sugar)" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_with_or_else =
        ord do
          asc ProjectionHelpers.score_prism(), or_else: 0
        end

      # nil treated as 0, so 0 < 100
      # This is equivalent to {ProjectionHelpers.score_prism(), 0}
      assert Ord.compare(charlie, alice, ord_with_or_else) == :lt
    end

    test "multiple 0-arity function calls" do
      people = [
        %Person{name: "Charlie", age: 30},
        %Person{name: "Alice", age: 30},
        %Person{name: "Bob", age: 25}
      ]

      ord_combined =
        ord do
          asc ProjectionHelpers.age_lens()
          asc ProjectionHelpers.name_lens()
        end

      sorted = Enum.sort(people, Ord.comparator(ord_combined))

      assert [
               %Person{name: "Bob"},
               %Person{name: "Alice"},
               %Person{name: "Charlie"}
             ] = sorted
    end

    test "captured function references for custom logic" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name_length =
        ord do
          asc &String.length(&1.name)
        end

      assert Ord.compare(alice, bob, ord_by_name_length) == :gt
    end

    test "anonymous function projection" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name_length =
        ord do
          asc fn person -> String.length(person.name) end
        end

      assert Ord.compare(alice, bob, ord_by_name_length) == :gt
    end

    test "combining helper functions with inline syntax" do
      people = [
        %Person{name: "Charlie", age: 30, score: nil},
        %Person{name: "Alice", age: 30, score: nil},
        %Person{name: "Bob", age: 25, score: 50}
      ]

      ord_combined =
        ord do
          asc ProjectionHelpers.age_lens()
          asc :score, or_else: 0
        end

      sorted = Enum.sort(people, Ord.comparator(ord_combined))

      # Bob (age 25, score 50) < Alice/Charlie (age 30, score 0)
      # Alice and Charlie both age 30, score 0, so order is stable
      assert %Person{name: "Bob"} = hd(sorted)
      assert Enum.at(sorted, 1).age == 30
      assert Enum.at(sorted, 2).age == 30
    end
  end

  # ============================================================================
  # Explicit Lens Projection Tests
  # ============================================================================

  describe "explicit Lens projections" do
    test "Lens.key for simple fields" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_age =
        ord do
          asc Lens.key(:age)
        end

      assert Ord.compare(bob, alice, ord_age) == :lt
    end

    test "Lens.path for nested fields" do
      alice = fixture(:alice_with_address)
      bob = fixture(:bob_with_address)

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      assert Ord.compare(alice, bob, ord_city) == :lt
    end
  end

  # ============================================================================
  # Explicit Prism Projection Tests
  # ============================================================================

  describe "explicit Prism with or_else" do
    test "Prism tuple with or_else value" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score =
        ord do
          asc {Prism.key(:score), 0}
        end

      assert Ord.compare(charlie, alice, ord_score) == :lt
    end
  end

  # ============================================================================
  # Bare Prism (Maybe.lift_ord) Tests
  # ============================================================================

  describe "bare Prism (Maybe.lift_ord)" do
    test "Nothing sorts before Just with asc" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score =
        ord do
          asc Prism.key(:score)
        end

      assert Ord.compare(charlie, alice, ord_score) == :lt
    end

    test "Nothing sorts after Just with desc" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score_desc =
        ord do
          desc Prism.key(:score)
        end

      assert Ord.compare(alice, charlie, ord_score_desc) == :lt
    end

    test "two Nothing values compare as equal" do
      charlie1 = %Person{name: "Alice", score: nil}
      charlie2 = %Person{name: "Bob", score: nil}

      ord_score =
        ord do
          asc Prism.key(:score)
        end

      # Both nil (Nothing), and no tiebreaker, so they compare as equal
      assert Ord.compare(charlie1, charlie2, ord_score) == :eq
    end

    test "bare Prism with nested path uses Maybe.lift_ord" do
      person_with_nested = %Person{
        name: "Alice",
        address: %Address{city: "Austin", state: "TX"}
      }

      person_without_nested = %Person{name: "Bob", address: nil}

      ord_state =
        ord do
          asc Prism.path([{Person, :address}, {Address, :state}])
        end

      # Nothing sorts before Just with asc
      assert Ord.compare(person_without_nested, person_with_nested, ord_state) == :lt
    end

    test "multiple bare Prisms in sequence" do
      p1 = %Person{name: "Alice", score: nil, age: 30}
      p2 = %Person{name: "Bob", score: 100, age: 25}
      p3 = %Person{name: "Charlie", score: nil, age: 35}

      ord_multi_prism =
        ord do
          asc Prism.key(:score)
          asc :age
        end

      # Both p1 and p3 have Nothing for score, so they tie on first projection
      # Then compare by age: p1.age=30 < p3.age=35
      assert Ord.compare(p1, p3, ord_multi_prism) == :lt

      # p1 has Nothing, p2 has Just, so Nothing < Just
      assert Ord.compare(p1, p2, ord_multi_prism) == :lt
    end
  end

  # ============================================================================
  # Behaviour Module Projection Tests
  # ============================================================================

  describe "behaviour module projections" do
    test "simple behaviour without options" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_name_length =
        ord do
          asc NameLength
        end

      assert Ord.compare(alice, bob, ord_name_length) == :gt
    end

    test "behaviour with options in asc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_weighted =
        ord do
          asc WeightedScore, weight: 2.0
        end

      assert Ord.compare(bob, alice, ord_weighted) == :lt
      assert Ord.compare(alice, bob, ord_weighted) == :gt
    end

    test "behaviour with options in desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_weighted_desc =
        ord do
          desc(WeightedScore, weight: 2.0)
        end

      assert Ord.compare(alice, bob, ord_weighted_desc) == :lt
      assert Ord.compare(bob, alice, ord_weighted_desc) == :gt
    end

    test "behaviour combined with other projections" do
      alice = %Person{name: "Alice", age: 30, score: 100}
      bob = %Person{name: "Bob", age: 25, score: 100}

      ord_combined =
        ord do
          desc(WeightedScore, weight: 1.5)
          asc NameLength
        end

      assert Ord.compare(alice, bob, ord_combined) == :gt
    end

    test "multiple behaviour modules in sequence" do
      alice = %Person{name: "Alice", age: 30, score: 100}
      bob = %Person{name: "Bob", age: 25, score: 100}
      charlie = %Person{name: "Charlie", age: 30, score: 100}

      ord_multi_behaviour =
        ord do
          desc(WeightedScore, weight: 1.0)
          asc NameLength
        end

      # Same weighted score (100), so compare by name length
      # "Alice" (5) < "Bob" (3) is false
      # "Alice" (5) < "Charlie" (7) is true
      assert Ord.compare(alice, charlie, ord_multi_behaviour) == :lt
      assert Ord.compare(bob, alice, ord_multi_behaviour) == :lt
    end

    test "behaviour returning nil compares nil as less than non-nil" do
      alice_with_bio = %Person{name: "Alice", age: 30, bio: "Engineer"}
      bob_without_bio = %Person{name: "Bob", age: 25, bio: nil}

      ord_bio =
        ord do
          asc OptionalBio
        end

      # Behaviour returns nil for bob_without_bio and "Engineer" for alice_with_bio
      # nil < "Engineer" in the DSL's ordering
      assert Ord.compare(bob_without_bio, alice_with_bio, ord_bio) == :lt
    end
  end

  # ============================================================================
  # Module with Ord Protocol Functions Tests
  # ============================================================================

  describe "module with ord protocol functions" do
    test "uses module directly with lt?/le?/gt?/ge? in asc" do
      ord_reverse =
        ord do
          asc ReverseStringOrd
        end

      # Sorts by reversed string: "cba" < "fed" < "zyx"
      assert Ord.compare("abc", "def", ord_reverse) == :lt
      assert Ord.compare("xyz", "def", ord_reverse) == :gt
      assert Ord.compare("abc", "abc", ord_reverse) == :eq
    end

    test "uses module directly with lt?/le?/gt?/ge? in desc" do
      ord_reverse_desc =
        ord do
          desc ReverseStringOrd
        end

      # Reversed sort: "zyx" > "fed" > "cba"
      assert Ord.compare("abc", "def", ord_reverse_desc) == :gt
      assert Ord.compare("xyz", "def", ord_reverse_desc) == :lt
    end

    test "combines module ord functions with other projections" do
      strings = ["xyz", "ab", "def", "abc"]

      ord_combined =
        ord do
          asc &String.length/1
          asc ReverseStringOrd
        end

      # First by length, then by reversed string
      # length 2 < 3
      assert Ord.compare("hi", "abc", ord_combined) == :lt
      # same length, "cba" < "zyx"
      assert Ord.compare("abc", "xyz", ord_combined) == :lt
      # same length, "cba" < "fed"
      assert Ord.compare("abc", "def", ord_combined) == :lt

      # Sort: by length first (2 < 3), then by reversed string within same length
      sorted = Enum.sort(strings, &(Ord.compare(&1, &2, ord_combined) == :lt))
      # "ab" (len 2), then len 3: "cba" < "fed" < "zyx"
      assert sorted == ["ab", "abc", "def", "xyz"]
    end
  end

  # ============================================================================
  # Protocol Dispatch Tests
  # ============================================================================

  describe "protocol dispatch" do
    test "uses custom Ord protocol implementation" do
      alice = fixture(:alice_with_address)
      bob = fixture(:bob_with_address)
      charlie = fixture(:charlie_with_address)

      ord_by_address =
        ord do
          asc :address
        end

      assert Ord.compare(bob, alice, ord_by_address) == :lt
      assert Ord.compare(alice, charlie, ord_by_address) == :lt
    end
  end

  # ============================================================================
  # Complex Composition Tests
  # ============================================================================

  describe "complex compositions" do
    test "multi-field sorting with tie-breaking" do
      people = [
        %Person{name: "Charlie", age: 30, score: nil},
        %Person{name: "Alice", age: 25, score: 100},
        %Person{name: "Bob", age: 30, score: 50},
        %Person{name: "Alice", age: 30, score: 100}
      ]

      ord_person =
        ord do
          asc :name
          desc :age
          asc :score, or_else: 0
        end

      sorted = Enum.sort(people, Ord.comparator(ord_person))

      assert sorted == [
               %Person{name: "Alice", age: 30, score: 100},
               %Person{name: "Alice", age: 25, score: 100},
               %Person{name: "Bob", age: 30, score: 50},
               %Person{name: "Charlie", age: 30, score: nil}
             ]
    end

    test "combining all projection types" do
      alice = %Person{
        name: "Alice",
        age: 30,
        score: 100,
        bio: "Software engineer",
        address: %Address{city: "Austin", state: "TX"}
      }

      bob = %Person{
        name: "Bob",
        age: 30,
        score: nil,
        bio: "Developer at big corp",
        address: %Address{city: "Austin", state: "TX"}
      }

      ord_complex =
        ord do
          asc Lens.path([:address, :state])
          desc :age
          asc Prism.key(:score)
          desc &String.length(&1.bio)
          asc NameLength
        end

      assert Ord.compare(bob, alice, ord_complex) == :lt
    end

    test "bare Prism sorting with Nothing values" do
      items = [
        %Person{name: "Alice", score: 100},
        %Person{name: "Bob", score: nil},
        %Person{name: "Charlie", score: 50},
        %Person{name: "Diana", score: nil}
      ]

      ord_score_then_name =
        ord do
          asc Prism.key(:score)
          asc :name
        end

      sorted = Enum.sort(items, Ord.comparator(ord_score_then_name))

      assert [
               %Person{name: "Bob"},
               %Person{name: "Diana"},
               %Person{name: "Charlie"},
               %Person{name: "Alice"}
             ] = sorted
    end
  end

  # ============================================================================
  # Compile-Time Error Tests
  # ============================================================================

  describe "compile-time errors" do
    test "rejects invalid projection type" do
      assert_raise CompileError, ~r/Invalid projection/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              asc %{invalid: :struct}
            end
          end
        )
      end
    end

    test "rejects module without Behaviour implementation" do
      defmodule NotABehaviour do
        def some_function, do: :ok
      end

      assert_raise CompileError, ~r/does not have lt\?\/2, ord\/1, or __struct__\/0/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              asc NotABehaviour
            end
          end
        )
      end
    end

    test "allows explicit Prism with or_else option" do
      # This now works - compiles to {Prism.key(:score), 0}
      {result, _binding} =
        Code.eval_quoted(
          quote do
            use Funx.Ord
            alias Funx.Optics.Prism
            alias Funx.Ord

            ord do
              asc Prism.key(:score), or_else: 0
            end
          end
        )

      # Verify it works with nil values
      alice = %{name: "Alice", score: 100}
      bob = %{name: "Bob", score: nil}

      assert Ord.compare(bob, alice, result) == :lt
    end

    test "rejects or_else with captured function projection" do
      assert_raise CompileError, ~r/cannot be used with captured functions/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              asc &String.length/1, or_else: 0
            end
          end
        )
      end
    end

    test "rejects or_else with Lens.key projection" do
      assert_raise CompileError, ~r/or_else.*only.*atom.*Prism/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord
            alias Funx.Optics.Lens

            ord do
              asc Lens.key(:name), or_else: "Unknown"
            end
          end
        )
      end
    end

    test "rejects or_else with Lens.path projection" do
      assert_raise CompileError, ~r/or_else.*only.*atom.*Prism/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord
            alias Funx.Optics.Lens

            ord do
              asc Lens.path([:address, :city]), or_else: "Unknown"
            end
          end
        )
      end
    end

    test "rejects or_else with behaviour module" do
      assert_raise CompileError, ~r/or_else.*only.*atom.*Prism/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              asc NameLength, or_else: 0
            end
          end
        )
      end
    end

    test "rejects or_else with ord variable" do
      assert_raise CompileError, ~r/or_else.*cannot be used with ord variables/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            base_ord =
              ord do
                asc :name
              end

            ord do
              asc base_ord, or_else: 0
            end
          end
        )
      end
    end

    test "rejects or_else with anonymous function" do
      assert_raise CompileError, ~r/cannot be used with anonymous functions/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              asc fn x -> x.name end, or_else: "Unknown"
            end
          end
        )
      end
    end

    test "rejects redundant or_else with tuple syntax" do
      assert_raise CompileError, ~r/already contains an or_else value/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord
            alias Funx.Optics.Prism

            ord do
              asc {Prism.key(:score), 0}, or_else: 10
            end
          end
        )
      end
    end

    test "rejects invalid DSL syntax" do
      assert_raise CompileError, ~r/Invalid Ord DSL syntax/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord

            ord do
              sort_by(:name)
            end
          end
        )
      end
    end
  end

  # ============================================================================
  # Runtime Error Tests
  # ============================================================================

  describe "runtime errors" do
    test "Lens.path raises BadMapError when intermediate value is nil" do
      person_with_address = fixture(:alice_with_address)
      person_without_address = %Person{name: "Bob", address: nil}

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      assert_raise BadMapError, fn ->
        Ord.compare(person_with_address, person_without_address, ord_city)
      end
    end

    test "Lens.path raises BadMapError when intermediate field is nil" do
      person_with_address = fixture(:alice_with_address)
      person_without_address = %Person{name: "Bob"}

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      assert_raise BadMapError, fn ->
        Ord.compare(person_with_address, person_without_address, ord_city)
      end
    end

    test "function projection raises when function fails on nil" do
      person1 = %Person{name: "Alice", bio: nil}
      person2 = %Person{name: "Bob", bio: "Developer"}

      ord_bio_length =
        ord do
          asc &String.length(&1.bio)
        end

      assert_raise FunctionClauseError, fn ->
        Ord.compare(person1, person2, ord_bio_length)
      end
    end

    test "Lens raises on invalid values (explicit Lens required)" do
      person_with_address = fixture(:alice_with_address)
      person_with_nil_address = %Person{name: "Bob", address: nil}

      # Must use explicit Lens to get raising behavior
      ord_by_address =
        ord do
          asc Lens.key(:address)
        end

      # Lens extracts nil, then Address.Ord.lt? tries to access .state on nil
      assert_raise KeyError, fn ->
        Ord.compare(person_with_address, person_with_nil_address, ord_by_address)
      end
    end

    test "atoms use Prism and handle nil safely (Nothing < Just)" do
      person_with_address = fixture(:alice_with_address)
      person_with_nil_address = %Person{name: "Bob", address: nil}

      # Atom uses Prism.key by default - safe for nil
      ord_by_address =
        ord do
          asc :address
        end

      # nil (Nothing) < Address struct (Just)
      result = Ord.compare(person_with_nil_address, person_with_address, ord_by_address)
      assert result == :lt
    end
  end

  # ============================================================================
  # Lens Tests - Total Access with Predictable Failures
  # ============================================================================

  describe "Lens - total access" do
    test "Lens.key works correctly when values exist" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_name =
        ord do
          asc Lens.key(:name)
        end

      assert Ord.compare(alice, bob, ord_name) == :lt
      assert Ord.compare(bob, alice, ord_name) == :gt
    end

    test "Lens.path works correctly with nested values" do
      alice_with_address = fixture(:alice_with_address)

      bob_with_address = %Person{
        name: "Bob",
        address: %Address{city: "Boston", state: "MA"}
      }

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      # "Austin" < "Boston"
      assert Ord.compare(alice_with_address, bob_with_address, ord_city) == :lt
    end

    test "Lens.key fails fast with KeyError when key is missing from struct" do
      s1 = %LimitedStruct{name: "Alice"}
      s2 = %Person{name: "Bob", age: 30}

      ord_age =
        ord do
          asc Lens.key(:age)
        end

      # LimitedStruct doesn't have :age key
      assert_raise KeyError, fn ->
        Ord.compare(s1, s2, ord_age)
      end
    end

    test "Lens.path fails fast with KeyError when intermediate key is missing" do
      person_no_address = %Person{name: "Alice", age: 30}
      person_with_address = fixture(:alice_with_address)

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      # Person struct has :address key, but its value is nil
      # Lens.path will try to access :city on nil and fail
      assert_raise BadMapError, fn ->
        Ord.compare(person_no_address, person_with_address, ord_city)
      end
    end

    test "Lens.key extracts nil values successfully and compares them" do
      s1 = %NullableStruct{name: "Alice", optional_field: nil}
      s2 = %NullableStruct{name: "Bob", optional_field: "value"}

      ord_optional =
        ord do
          asc Lens.key(:optional_field)
        end

      # Lens extracts nil from s1, then compares nil < "value" (which is true in Elixir)
      assert Ord.compare(s1, s2, ord_optional) == :lt
    end

    test "Lens vs Prism - different behavior with nil values" do
      c1 = %Container{value: nil}
      c2 = %Container{value: 10}

      # Lens extracts nil, compares nil > 10 (in Elixir's term ordering, atoms > numbers)
      ord_lens =
        ord do
          asc Lens.key(:value)
        end

      # Prism treats nil as Nothing, which comes before Just values
      ord_prism =
        ord do
          asc :value
        end

      # Different results!
      # Lens: nil (atom) > 10 (number) in Elixir's term ordering
      assert Ord.compare(c1, c2, ord_lens) == :gt

      # Prism: Nothing < Just(10) - semantic ordering
      assert Ord.compare(c1, c2, ord_prism) == :lt

      # This shows the key difference:
      # - Lens: Uses Elixir's term ordering (atoms > numbers, so nil > 10)
      # - Prism: Uses Maybe semantics (Nothing < Just, so nil < 10)
    end

    test "Lens with multi-level nested paths" do
      e1 = %Employee{
        name: "Alice",
        company: %Company{
          name: "Acme",
          address: %Address{city: "Austin", state: "TX"}
        }
      }

      e2 = %Employee{
        name: "Bob",
        company: %Company{
          name: "Widgets Inc",
          address: %Address{city: "Boston", state: "MA"}
        }
      }

      ord_company_city =
        ord do
          asc Lens.path([:company, :address, :city])
        end

      # "Austin" < "Boston"
      assert Ord.compare(e1, e2, ord_company_city) == :lt
    end

    test "Lens fails predictably with descriptive error on deeply nested missing key" do
      # Note: Using CompanyNoAddress struct without :address field
      e1 = %Employee{name: "Alice", company: %CompanyNoAddress{name: "Acme"}}
      e2 = %Employee{name: "Bob", company: %Company{name: "Widgets"}}

      ord_company_city =
        ord do
          asc Lens.path([:company, :address, :city])
        end

      # Company doesn't have :address key
      assert_raise KeyError, ~r/:address/, fn ->
        Ord.compare(e1, e2, ord_company_city)
      end
    end

    test "multiple Lens projections in same ord" do
      alice_with_address = fixture(:alice_with_address)

      bob_same_city = %Person{
        name: "Bob",
        age: 25,
        address: %Address{city: "Austin", state: "TX"}
      }

      ord_city_then_age =
        ord do
          asc Lens.path([:address, :city])
          asc Lens.key(:age)
        end

      # Same city "Austin", so compares by age: 30 < 25 is false
      assert Ord.compare(alice_with_address, bob_same_city, ord_city_then_age) == :gt
    end

    test "very deep Lens.path with 5 levels of nesting" do
      d1 = %Department{
        name: "Engineering",
        office: %Office{
          name: "HQ",
          city: %City{
            name: "Austin",
            region: %Region{
              name: "Central",
              country: %Country{name: "USA", code: "US"}
            }
          }
        }
      }

      d2 = %Department{
        name: "Engineering",
        office: %Office{
          name: "HQ",
          city: %City{
            name: "Austin",
            region: %Region{
              name: "Central",
              country: %Country{name: "Canada", code: "CA"}
            }
          }
        }
      }

      d3 = %Department{
        name: "Sales",
        office: %Office{
          name: "Branch",
          city: %City{
            name: "Boston",
            region: %Region{
              name: "Northeast",
              country: %Country{name: "USA", code: "US"}
            }
          }
        }
      }

      ord_country_code =
        ord do
          asc Lens.path([:office, :city, :region, :country, :code])
        end

      # "CA" < "US"
      assert Ord.compare(d2, d1, ord_country_code) == :lt
      # d1 and d3 both have "US", and no tiebreaker, so they compare as equal
      assert Ord.compare(d1, d3, ord_country_code) == :eq

      ord_region_name =
        ord do
          asc Lens.path([:office, :city, :region, :name])
        end

      # "Central" < "Northeast"
      assert Ord.compare(d1, d3, ord_region_name) == :lt
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "empty ord block returns identity ordering" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_empty =
        ord do
        end

      assert Ord.compare(alice, bob, ord_empty) == :eq
      assert Ord.compare(bob, alice, ord_empty) == :eq
      assert Ord.compare(alice, alice, ord_empty) == :eq
    end

    test "equal values on projection field compare as equal" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 25}

      ord_name =
        ord do
          asc :name
        end

      # Same name, and no implicit tiebreaker, so they compare as equal
      assert Ord.compare(alice1, alice2, ord_name) == :eq
    end

    test "first projection has priority in tie-breaking" do
      people = [
        %Person{name: "Bob", age: 30},
        %Person{name: "Alice", age: 25},
        %Person{name: "Alice", age: 30},
        %Person{name: "Bob", age: 25}
      ]

      ord_name_then_age =
        ord do
          asc :name
          asc :age
        end

      sorted = Enum.sort(people, Ord.comparator(ord_name_then_age))

      assert [
               %Person{name: "Alice", age: 25},
               %Person{name: "Alice", age: 30},
               %Person{name: "Bob", age: 25},
               %Person{name: "Bob", age: 30}
             ] = sorted
    end
  end

  # ============================================================================
  # Explicit Protocol Tiebreaker Tests
  # ============================================================================

  describe "explicit protocol tiebreaker" do
    test "Ord.Protocol as explicit tiebreaker uses struct's Ord implementation" do
      # Two workers in same department, different worker_ids
      worker1 = %Worker{department: "Engineering", name: "Alice", worker_id: 100}
      worker2 = %Worker{department: "Engineering", name: "Bob", worker_id: 50}

      # Without tiebreaker - same department, so equal
      ord_dept_only =
        ord do
          asc :department
        end

      assert Ord.compare(worker1, worker2, ord_dept_only) == :eq

      # With explicit Ord.Protocol tiebreaker - uses Worker's Ord (by worker_id)
      ord_dept_with_tiebreaker =
        ord do
          asc :department
          asc Funx.Ord.Protocol
        end

      # worker2 (id=50) < worker1 (id=100) by Worker's Ord implementation
      assert Ord.compare(worker2, worker1, ord_dept_with_tiebreaker) == :lt
      assert Ord.compare(worker1, worker2, ord_dept_with_tiebreaker) == :gt
    end

    test "Ord.Protocol tiebreaker sorts correctly" do
      workers = [
        %Worker{department: "Sales", name: "Charlie", worker_id: 300},
        %Worker{department: "Engineering", name: "Alice", worker_id: 100},
        %Worker{department: "Engineering", name: "Bob", worker_id: 50},
        %Worker{department: "Sales", name: "Diana", worker_id: 25}
      ]

      ord_dept_then_protocol =
        ord do
          asc :department
          asc Funx.Ord.Protocol
        end

      sorted = Enum.sort(workers, Ord.comparator(ord_dept_then_protocol))

      # First by department (Engineering < Sales), then by worker_id within department
      assert [
               %Worker{department: "Engineering", worker_id: 50},
               %Worker{department: "Engineering", worker_id: 100},
               %Worker{department: "Sales", worker_id: 25},
               %Worker{department: "Sales", worker_id: 300}
             ] = sorted
    end

    test "Ord.Protocol on type without implementation uses Elixir term ordering" do
      # Person doesn't have a custom Ord implementation, so falls back to Any
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 25}

      ord_name_with_protocol_tiebreaker =
        ord do
          asc :name
          asc Funx.Ord.Protocol
        end

      # Same name, but Ord.Protocol falls back to Any (Elixir term ordering)
      # age: 25 < age: 30 in term ordering
      assert Ord.compare(alice2, alice1, ord_name_with_protocol_tiebreaker) == :lt
      assert Ord.compare(alice1, alice2, ord_name_with_protocol_tiebreaker) == :gt
    end

    test "desc Ord.Protocol reverses the tiebreaker ordering" do
      worker1 = %Worker{department: "Engineering", name: "Alice", worker_id: 100}
      worker2 = %Worker{department: "Engineering", name: "Bob", worker_id: 50}

      ord_dept_desc_tiebreaker =
        ord do
          asc :department
          desc Funx.Ord.Protocol
        end

      # Reversed: worker1 (id=100) < worker2 (id=50) in desc order
      assert Ord.compare(worker1, worker2, ord_dept_desc_tiebreaker) == :lt
      assert Ord.compare(worker2, worker1, ord_dept_desc_tiebreaker) == :gt
    end
  end

  # ============================================================================
  # Bare Struct Module for Type Filtering
  # ============================================================================

  describe "bare struct module as type filter" do
    test "bare struct module filters by type without struct field comparison" do
      cc_1 = %CreditCard{name: "Charles", number: "4111", expiry: "12/26", amount: 400}
      cc_2 = %CreditCard{name: "Alice", number: "4242", expiry: "01/27", amount: 300}
      cc_3 = %CreditCard{name: "Beth", number: nil, expiry: "06/25", amount: 100}

      check_1 = %Check{
        name: "Frank",
        routing_number: "111000025",
        account_number: "0001234567",
        amount: 100
      }

      check_2 = %Check{
        name: "Edith",
        routing_number: "121042882",
        account_number: "0009876543",
        amount: 400
      }

      check_3 = %Check{
        name: "Daves",
        routing_number: "026009593",
        account_number: "0005551122",
        amount: 200
      }

      payment_data = [check_1, check_2, check_3, cc_1, cc_2, cc_3]

      # Use bare Check module for type filtering
      route_name_ord =
        ord do
          desc Check
          asc Prism.key(:routing_number)
          asc Lens.key(:name)
        end

      result = Funx.List.sort(payment_data, route_name_ord)

      # Extract just the Checks and CreditCards
      checks = Enum.filter(result, &match?(%Check{}, &1))
      ccs = Enum.filter(result, &match?(%CreditCard{}, &1))

      # Verify Checks come first
      assert length(checks) == 3
      assert length(ccs) == 3

      # Verify Checks are sorted by routing_number ascending
      routing_numbers = Enum.map(checks, & &1.routing_number)
      assert routing_numbers == ["026009593", "111000025", "121042882"]

      # Verify Check names match expected order
      check_names = Enum.map(checks, & &1.name)
      assert check_names == ["Daves", "Frank", "Edith"]

      # Verify all Checks come before all CreditCards
      all_items =
        Enum.map(result, fn
          %Check{name: n} -> {:check, n}
          %CreditCard{name: n} -> {:cc, n}
        end)

      {checks_part, ccs_part} = Enum.split_while(all_items, fn {type, _} -> type == :check end)
      assert length(checks_part) == 3
      assert length(ccs_part) == 3
    end

    test "bare struct module creates function returning true/false" do
      check = %Check{name: "Alice", routing_number: "111", account_number: "001", amount: 100}
      cc = %CreditCard{name: "Bob", number: "4242", expiry: "01/27", amount: 300}

      ord =
        ord do
          desc Check
        end

      # Both Checks should return same value (true), CreditCards return false
      # So Checks compare equal to each other, and all Checks > all CreditCards (when desc)
      checks_sorted = Funx.List.sort([check, check], ord)
      assert checks_sorted == [check, check]

      mixed_sorted = Funx.List.sort([cc, check], ord)
      assert mixed_sorted == [check, cc]
    end

    test "multiple bare struct modules for multi-level partitioning" do
      check = %Check{name: "Frank", routing_number: "111", account_number: "001", amount: 100}
      cc = %CreditCard{name: "Alice", number: "4242", expiry: "01/27", amount: 300}
      person = %Person{name: "Bob", age: 30}

      # Sort: Checks first, then CreditCards, then Persons, all by name
      ord =
        ord do
          desc Check
          desc CreditCard
          asc Lens.key(:name)
        end

      result = Funx.List.sort([person, cc, check], ord)

      # Checks first, then CreditCards, then Persons
      assert match?([%Check{}, %CreditCard{}, %Person{}], result)
    end

    test "bare struct avoids struct field ordering interference" do
      # Create Checks where account_number order differs from routing_number order
      check_a = %Check{
        name: "Alice",
        routing_number: "222000000",
        account_number: "0001111111",
        amount: 100
      }

      check_b = %Check{
        name: "Bob",
        routing_number: "111000000",
        account_number: "9999999999",
        amount: 200
      }

      check_c = %Check{
        name: "Charlie",
        routing_number: "333000000",
        account_number: "5555555555",
        amount: 150
      }

      # With bare struct - all Checks return true, so they're equal on first criterion
      ord =
        ord do
          desc Check
          asc Prism.key(:routing_number)
        end

      result = Funx.List.sort([check_c, check_a, check_b], ord)

      # Verify routing_number is sorted correctly in ascending order
      routing_numbers = Enum.map(result, & &1.routing_number)
      assert routing_numbers == ["111000000", "222000000", "333000000"]

      # Verify the order matches the expected Checks
      assert [check_b, check_a, check_c] == result
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: Ord laws" do
    property "totality: all values can be compared" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric),
              age1 <- integer(0..100),
              age2 <- integer(0..100)
            ) do
        p1 = %Person{name: name1, age: age1}
        p2 = %Person{name: name2, age: age2}

        ord_person =
          ord do
            asc :name
            asc :age
          end

        # compare always returns a valid ordering
        result = Ord.compare(p1, p2, ord_person)
        assert result in [:lt, :eq, :gt]
      end
    end

    property "reflexivity: x compared to itself is always :eq" do
      check all(
              name <- string(:alphanumeric),
              age <- integer(0..100)
            ) do
        person = %Person{name: name, age: age}

        ord_person =
          ord do
            asc :name
            desc :age
          end

        assert Ord.compare(person, person, ord_person) == :eq
      end
    end

    property "antisymmetry: if x <= y and y <= x, then x == y" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric),
              age1 <- integer(0..100),
              age2 <- integer(0..100)
            ) do
        p1 = %Person{name: name1, age: age1}
        p2 = %Person{name: name2, age: age2}

        ord_person =
          ord do
            asc :name
            asc :age
          end

        cmp_12 = Ord.compare(p1, p2, ord_person)
        cmp_21 = Ord.compare(p2, p1, ord_person)

        if cmp_12 in [:lt, :eq] and cmp_21 in [:lt, :eq] do
          # Both x <= y and y <= x, so must be equal
          assert cmp_12 == :eq
          assert cmp_21 == :eq
        end
      end
    end

    property "transitivity: if x < y and y < z, then x < z" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric),
              name3 <- string(:alphanumeric),
              age1 <- integer(0..100),
              age2 <- integer(0..100),
              age3 <- integer(0..100)
            ) do
        p1 = %Person{name: name1, age: age1}
        p2 = %Person{name: name2, age: age2}
        p3 = %Person{name: name3, age: age3}

        ord_person =
          ord do
            asc :name
            asc :age
          end

        cmp_12 = Ord.compare(p1, p2, ord_person)
        cmp_23 = Ord.compare(p2, p3, ord_person)
        cmp_13 = Ord.compare(p1, p3, ord_person)

        if cmp_12 == :lt and cmp_23 == :lt do
          # If x < y and y < z, then x < z
          assert cmp_13 == :lt
        end

        if cmp_12 == :gt and cmp_23 == :gt do
          # If x > y and y > z, then x > z
          assert cmp_13 == :gt
        end
      end
    end

    property "consistency with sort: sorted lists are ordered" do
      check all(
              people <-
                list_of(
                  tuple({string(:alphanumeric), integer(0..100)}),
                  min_length: 2,
                  max_length: 10
                )
            ) do
        persons = Enum.map(people, fn {name, age} -> %Person{name: name, age: age} end)

        ord_person =
          ord do
            asc :name
            asc :age
          end

        sorted = Enum.sort(persons, Ord.comparator(ord_person))

        # Verify that consecutive elements are in order
        sorted
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [p1, p2] ->
          result = Ord.compare(p1, p2, ord_person)
          assert result in [:lt, :eq]
        end)
      end
    end
  end

  describe "property: projection behavior" do
    property "asc projection maintains order" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric)
            ) do
        p1 = %Person{name: name1}
        p2 = %Person{name: name2}

        ord_name =
          ord do
            asc :name
          end

        dsl_result = Ord.compare(p1, p2, ord_name)
        direct_result = if name1 < name2, do: :lt, else: if(name1 > name2, do: :gt, else: :eq)

        assert dsl_result == direct_result
      end
    end

    property "desc projection reverses order" do
      check all(
              age1 <- integer(0..100),
              age2 <- integer(0..100)
            ) do
        p1 = %Person{age: age1}
        p2 = %Person{age: age2}

        ord_age_desc =
          ord do
            desc :age
          end

        dsl_result = Ord.compare(p1, p2, ord_age_desc)
        # desc reverses: if age1 < age2, result should be :gt
        direct_result = if age1 > age2, do: :lt, else: if(age1 < age2, do: :gt, else: :eq)

        assert dsl_result == direct_result
      end
    end

    property "or_else provides fallback for nil values" do
      check all(
              score <- one_of([integer(0..1000), constant(nil)]),
              default <- integer(0..100)
            ) do
        person = %Person{score: score}

        ord_score =
          ord do
            asc :score, or_else: default
          end

        # Should not raise - or_else handles nil
        result = Ord.compare(person, person, ord_score)
        assert result == :eq
      end
    end

    property "multiple projections compose lexicographically" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric),
              age1 <- integer(0..100),
              age2 <- integer(0..100)
            ) do
        p1 = %Person{name: name1, age: age1}
        p2 = %Person{name: name2, age: age2}

        ord_composed =
          ord do
            asc :name
            asc :age
          end

        result = Ord.compare(p1, p2, ord_composed)

        # Manual lexicographic comparison
        expected =
          cond do
            name1 < name2 -> :lt
            name1 > name2 -> :gt
            age1 < age2 -> :lt
            age1 > age2 -> :gt
            true -> :eq
          end

        assert result == expected
      end
    end
  end

  describe "property: bare Prism with Maybe.lift_ord" do
    property "Nothing always compares less than Just with asc" do
      check all(score <- integer(0..1000)) do
        with_score = %Person{score: score}
        without_score = %Person{score: nil}

        ord_score =
          ord do
            asc Prism.key(:score)
          end

        # Nothing < Just for asc
        assert Ord.compare(without_score, with_score, ord_score) == :lt
        assert Ord.compare(with_score, without_score, ord_score) == :gt
      end
    end

    property "Nothing always compares greater than Just with desc" do
      check all(score <- integer(0..1000)) do
        with_score = %Person{score: score}
        without_score = %Person{score: nil}

        ord_score_desc =
          ord do
            desc Prism.key(:score)
          end

        # Nothing > Just for desc (reversed)
        assert Ord.compare(with_score, without_score, ord_score_desc) == :lt
        assert Ord.compare(without_score, with_score, ord_score_desc) == :gt
      end
    end

    property "two Nothing values compare as equal" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric)
            ) do
        p1 = %Person{name: name1, score: nil}
        p2 = %Person{name: name2, score: nil}

        ord_score =
          ord do
            asc Prism.key(:score)
          end

        # Both are Nothing on :score, and no tiebreaker, so they compare as equal
        assert Ord.compare(p1, p2, ord_score) == :eq
      end
    end
  end

  describe "property: function projections" do
    property "function projection extracts and compares correctly" do
      check all(
              bio1 <- string(:alphanumeric, min_length: 1, max_length: 50),
              bio2 <- string(:alphanumeric, min_length: 1, max_length: 50)
            ) do
        p1 = %Person{bio: bio1}
        p2 = %Person{bio: bio2}

        ord_bio_length =
          ord do
            asc &String.length(&1.bio)
          end

        result = Ord.compare(p1, p2, ord_bio_length)
        len1 = String.length(bio1)
        len2 = String.length(bio2)

        expected =
          cond do
            len1 < len2 -> :lt
            len1 > len2 -> :gt
            # Same length: no tiebreaker, so equal
            true -> :eq
          end

        assert result == expected
      end
    end
  end

  describe "property: identity and empty orderings" do
    property "empty ord treats all values as equal" do
      check all(
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric),
              age1 <- integer(0..100),
              age2 <- integer(0..100)
            ) do
        p1 = %Person{name: name1, age: age1}
        p2 = %Person{name: name2, age: age2}

        ord_empty =
          ord do
          end

        # Empty ord means all values are equal
        assert Ord.compare(p1, p2, ord_empty) == :eq
      end
    end
  end

  # ============================================================================
  # Ord Variable Projection Tests
  # ============================================================================

  describe "ord variable projections" do
    test "asc with ord variable preserves base ordering" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      name_ord =
        ord do
          asc :name
        end

      combined_ord =
        ord do
          asc name_ord
        end

      assert Ord.compare(alice, bob, combined_ord) == :lt
      assert Ord.compare(bob, alice, combined_ord) == :gt
      assert Ord.compare(alice, alice, combined_ord) == :eq
    end

    test "desc with ord variable reverses base ordering" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      name_ord =
        ord do
          asc :name
        end

      reversed_ord =
        ord do
          desc name_ord
        end

      assert Ord.compare(alice, bob, reversed_ord) == :gt
      assert Ord.compare(bob, alice, reversed_ord) == :lt
      assert Ord.compare(alice, alice, reversed_ord) == :eq
    end

    test "ord variable preserves multi-field ordering" do
      people = [
        %Person{name: "Charlie", age: 30, score: nil},
        %Person{name: "Alice", age: 25, score: 100},
        %Person{name: "Bob", age: 30, score: 50}
      ]

      name_age_ord =
        ord do
          asc :name
          desc :age
        end

      combined_ord =
        ord do
          asc name_age_ord
        end

      sorted = Enum.sort(people, Ord.comparator(combined_ord))

      assert [
               %Person{name: "Alice", age: 25, score: 100},
               %Person{name: "Bob", age: 30, score: 50},
               %Person{name: "Charlie", age: 30, score: nil}
             ] = sorted
    end

    test "double reversal restores original order" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      base_ord =
        ord do
          asc :age
        end

      reversed_once =
        ord do
          desc base_ord
        end

      reversed_twice =
        ord do
          desc reversed_once
        end

      # Should match the original ordering
      assert Ord.compare(bob, alice, base_ord) == Ord.compare(bob, alice, reversed_twice)
      assert Ord.compare(alice, bob, base_ord) == Ord.compare(alice, bob, reversed_twice)
    end

    test "composing two ord variables in sequence" do
      people = [
        %Person{name: "Alice", age: 30, score: 100},
        %Person{name: "Alice", age: 25, score: 50},
        %Person{name: "Bob", age: 30, score: nil}
      ]

      name_ord =
        ord do
          asc :name
        end

      age_ord =
        ord do
          desc :age
        end

      combined =
        ord do
          asc name_ord
          asc age_ord
        end

      sorted = Enum.sort(people, Ord.comparator(combined))

      # Sorted by name asc, then age desc (30 before 25)
      assert [
               %Person{name: "Alice", age: 30, score: 100},
               %Person{name: "Alice", age: 25, score: 50},
               %Person{name: "Bob", age: 30, score: nil}
             ] = sorted
    end

    test "mixing ord variables with regular projections" do
      people = [
        %Person{name: "Alice", age: 30, score: nil},
        %Person{name: "Bob", age: 25, score: 100},
        %Person{name: "Charlie", age: 30, score: 50}
      ]

      name_age_ord =
        ord do
          asc :name
          desc :age
        end

      combined =
        ord do
          asc :score, or_else: 0
          desc name_age_ord
        end

      sorted = Enum.sort(people, Ord.comparator(combined))

      assert [
               %Person{name: "Alice", age: 30, score: nil},
               %Person{name: "Charlie", age: 30, score: 50},
               %Person{name: "Bob", age: 25, score: 100}
             ] = sorted
    end

    test "ord variable before and after other projections" do
      people = [
        %Person{name: "Alice", age: 30, score: 100},
        %Person{name: "Bob", age: 30, score: 100},
        %Person{name: "Charlie", age: 25, score: 100}
      ]

      name_ord =
        ord do
          asc :name
        end

      age_ord =
        ord do
          desc :age
        end

      combined =
        ord do
          asc age_ord
          asc :score
          asc name_ord
        end

      sorted = Enum.sort(people, Ord.comparator(combined))

      assert [
               %Person{name: "Alice", age: 30, score: 100},
               %Person{name: "Bob", age: 30, score: 100},
               %Person{name: "Charlie", age: 25, score: 100}
             ] = sorted
    end

    test "reversing complex multi-prism ordering" do
      payment_amount_ord =
        ord do
          asc Prism.key(:credit_card_payment)
          asc Prism.key(:credit_card_refund)
          asc Prism.key(:check_payment)
          asc Prism.key(:check_refund)
        end

      payment_amount_rev_ord =
        ord do
          desc payment_amount_ord
        end

      data1 = %{credit_card_payment: 50}
      data2 = %{credit_card_payment: 100}
      data3 = %{credit_card_payment: 75}

      # Forward: 50 < 75 < 100
      assert Ord.compare(data1, data2, payment_amount_ord) == :lt
      assert Ord.compare(data1, data3, payment_amount_ord) == :lt
      assert Ord.compare(data3, data2, payment_amount_ord) == :lt

      # Reversed: 100 > 75 > 50
      assert Ord.compare(data2, data3, payment_amount_rev_ord) == :lt
      assert Ord.compare(data2, data1, payment_amount_rev_ord) == :lt
      assert Ord.compare(data3, data1, payment_amount_rev_ord) == :lt
    end

    test "extending base ordering with additional criteria" do
      base_ord =
        ord do
          asc :age
        end

      extended_ord =
        ord do
          asc base_ord
          asc :name
        end

      alice = %Person{name: "Alice", age: 30, score: nil}
      bob = %Person{name: "Bob", age: 30, score: nil}

      assert Ord.compare(alice, bob, extended_ord) == :lt
    end

    test "empty ord variable falls through to next projection" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      empty_ord =
        ord do
        end

      combined =
        ord do
          asc empty_ord
          asc :name
        end

      assert Ord.compare(alice, bob, combined) == :lt
    end

    test "nested ord variables compose correctly" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_level1 =
        ord do
          asc :name
        end

      ord_level2 =
        ord do
          desc ord_level1
        end

      ord_level3 =
        ord do
          asc ord_level2
        end

      assert Ord.compare(alice, bob, ord_level3) == :gt
    end

    test "raises when variable is not an ord map" do
      alice = fixture(:alice)
      bob = fixture(:bob)
      invalid_value = "not an ord"

      assert_raise RuntimeError, ~r/Expected an Ord map/, fn ->
        combined =
          ord do
            asc invalid_value
          end

        Ord.compare(alice, bob, combined)
      end
    end

    test "raises when variable is nil" do
      alice = fixture(:alice)
      bob = fixture(:bob)
      nil_value = nil

      assert_raise RuntimeError, ~r/Expected an Ord map/, fn ->
        combined =
          ord do
            asc nil_value
          end

        Ord.compare(alice, bob, combined)
      end
    end

    test "raises when variable is a map but not an ord map" do
      alice = fixture(:alice)
      bob = fixture(:bob)
      fake_ord = %{some: "map"}

      assert_raise RuntimeError, ~r/Expected an Ord map/, fn ->
        combined =
          ord do
            asc fake_ord
          end

        Ord.compare(alice, bob, combined)
      end
    end

    test "ord variable from inline assignment works with asc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      name_ord =
        ord do
          asc :name
        end

      combined =
        ord do
          asc name_ord
        end

      assert Ord.compare(alice, bob, combined) == :lt
    end

    test "ord variable from inline assignment works with desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      age_desc =
        ord do
          desc :age
        end

      combined =
        ord do
          desc age_desc
        end

      assert Ord.compare(alice, bob, combined) == :gt
    end

    test "contramap ord works as ord variable" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      name_length_ord = Ord.contramap(&String.length(&1.name))

      combined =
        ord do
          asc name_length_ord
        end

      assert Ord.compare(bob, alice, combined) == :lt
      assert Ord.compare(alice, bob, combined) == :gt
    end
  end
end
