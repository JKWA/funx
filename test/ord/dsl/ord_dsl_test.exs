defmodule Funx.Ord.Dsl.OrdDslTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use Funx.Ord.Dsl

  alias Funx.Optics.{Lens, Prism}
  alias Funx.Ord.Utils

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule Person do
    defstruct [:name, :age, :score, :address, :bio]
  end

  defmodule Address do
    defstruct [:street, :city, :state, :zip]
  end

  # ============================================================================
  # Protocol Implementations
  # ============================================================================

  defimpl Funx.Ord, for: Address do
    def lt?(a, b), do: {a.state, a.city} < {b.state, b.city}
    def le?(a, b), do: {a.state, a.city} <= {b.state, b.city}
    def gt?(a, b), do: {a.state, a.city} > {b.state, b.city}
    def ge?(a, b), do: {a.state, a.city} >= {b.state, b.city}
  end

  # ============================================================================
  # Custom Behaviour Projections
  # ============================================================================

  defmodule NameLength do
    @behaviour Funx.Ord.Dsl.Behaviour

    @impl true
    def project(person, _opts) do
      String.length(person.name)
    end
  end

  defmodule WeightedScore do
    @behaviour Funx.Ord.Dsl.Behaviour

    @impl true
    def project(person, opts) do
      weight = Keyword.get(opts, :weight, 1.0)
      (person.score || 0) * weight
    end
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

      assert Utils.compare(alice, bob, ord_name) == :lt
      assert Utils.compare(bob, alice, ord_name) == :gt
    end

    test "desc sorts in descending order" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_name_desc =
        ord do
          desc :name
        end

      assert Utils.compare(alice, bob, ord_name_desc) == :gt
      assert Utils.compare(bob, alice, ord_name_desc) == :lt
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

      assert Utils.compare(alice_25, alice_30, ord_name_then_age) == :lt
      assert Utils.compare(alice_30, bob_30, ord_name_then_age) == :lt
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
      assert Utils.compare(alice, bob, ord_desc_age_asc_name) == :lt
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

      assert Utils.compare(without_score, with_score, ord_score) == :lt
    end

    test "combines with other projections" do
      alice_no_score = %Person{name: "Alice", age: 30, score: nil}
      bob_with_score = %Person{name: "Bob", age: 25, score: 50}

      ord_score_then_age =
        ord do
          asc :score, or_else: 0
          desc :age
        end

      assert Utils.compare(alice_no_score, bob_with_score, ord_score_then_age) == :lt
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

      assert Utils.compare(bob, alice, ord_bio_length) == :lt
    end

    test "captured function" do
      items = ["apple", "kiwi", "banana"]

      ord_length =
        ord do
          asc &String.length/1
        end

      sorted = Enum.sort(items, Utils.comparator(ord_length))
      assert sorted == ["kiwi", "apple", "banana"]
    end

    test "anonymous function with desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_bio_length_desc =
        ord do
          desc &String.length(&1.bio)
        end

      assert Utils.compare(alice, bob, ord_bio_length_desc) == :lt
    end
  end

  # ============================================================================
  # Remote Function Call Tests
  # ============================================================================

  describe "reusable projections via helper functions" do
    defmodule ProjectionHelpers do
      # 0-arity functions that return projections
      def name_lens, do: Lens.key(:name)
      def age_lens, do: Lens.key(:age)
      def score_prism, do: Prism.key(:score)
      def score_with_or_else, do: {Prism.key(:score), 0}
    end

    test "0-arity function returning Lens" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name =
        ord do
          asc ProjectionHelpers.name_lens()
        end

      assert Utils.compare(alice, bob, ord_by_name) == :lt
    end

    test "0-arity function returning bare Prism" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score =
        ord do
          asc ProjectionHelpers.score_prism()
        end

      # Nothing < Just with bare Prism
      assert Utils.compare(charlie, alice, ord_score) == :lt
    end

    test "0-arity function returning Prism tuple with or_else" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_with_or_else =
        ord do
          asc ProjectionHelpers.score_with_or_else()
        end

      # nil treated as 0, so 0 < 100
      assert Utils.compare(charlie, alice, ord_with_or_else) == :lt
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
      assert Utils.compare(charlie, alice, ord_with_or_else) == :lt
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

      sorted = Enum.sort(people, Utils.comparator(ord_combined))

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

      assert Utils.compare(alice, bob, ord_by_name_length) == :gt
    end

    test "anonymous function projection" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_by_name_length =
        ord do
          asc fn person -> String.length(person.name) end
        end

      assert Utils.compare(alice, bob, ord_by_name_length) == :gt
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

      sorted = Enum.sort(people, Utils.comparator(ord_combined))

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

      assert Utils.compare(bob, alice, ord_age) == :lt
    end

    test "Lens.path for nested fields" do
      alice = fixture(:alice_with_address)
      bob = fixture(:bob_with_address)

      ord_city =
        ord do
          asc Lens.path([:address, :city])
        end

      assert Utils.compare(alice, bob, ord_city) == :lt
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

      assert Utils.compare(charlie, alice, ord_score) == :lt
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

      assert Utils.compare(charlie, alice, ord_score) == :lt
    end

    test "Nothing sorts after Just with desc" do
      alice = fixture(:alice)
      charlie = fixture(:charlie)

      ord_score_desc =
        ord do
          desc Prism.key(:score)
        end

      assert Utils.compare(alice, charlie, ord_score_desc) == :lt
    end

    test "two Nothing values compare as equal" do
      charlie1 = %Person{name: "Alice", score: nil}
      charlie2 = %Person{name: "Bob", score: nil}

      ord_score =
        ord do
          asc Prism.key(:score)
        end

      assert Utils.compare(charlie1, charlie2, ord_score) == :eq
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
      assert Utils.compare(person_without_nested, person_with_nested, ord_state) == :lt
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
      assert Utils.compare(p1, p3, ord_multi_prism) == :lt

      # p1 has Nothing, p2 has Just, so Nothing < Just
      assert Utils.compare(p1, p2, ord_multi_prism) == :lt
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

      assert Utils.compare(alice, bob, ord_name_length) == :gt
    end

    test "behaviour with options in asc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_weighted =
        ord do
          asc WeightedScore, weight: 2.0
        end

      assert Utils.compare(bob, alice, ord_weighted) == :lt
      assert Utils.compare(alice, bob, ord_weighted) == :gt
    end

    test "behaviour with options in desc" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_weighted_desc =
        ord do
          desc(WeightedScore, weight: 2.0)
        end

      assert Utils.compare(alice, bob, ord_weighted_desc) == :lt
      assert Utils.compare(bob, alice, ord_weighted_desc) == :gt
    end

    test "behaviour combined with other projections" do
      alice = %Person{name: "Alice", age: 30, score: 100}
      bob = %Person{name: "Bob", age: 25, score: 100}

      ord_combined =
        ord do
          desc(WeightedScore, weight: 1.5)
          asc NameLength
        end

      assert Utils.compare(alice, bob, ord_combined) == :gt
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

      assert Utils.compare(bob, alice, ord_by_address) == :lt
      assert Utils.compare(alice, charlie, ord_by_address) == :lt
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

      sorted = Enum.sort(people, Utils.comparator(ord_person))

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

      assert Utils.compare(bob, alice, ord_complex) == :lt
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

      sorted = Enum.sort(items, Utils.comparator(ord_score_then_name))

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
            use Funx.Ord.Dsl

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

      assert_raise CompileError, ~r/must implement Funx\.Ord\.Dsl\.Behaviour/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord.Dsl

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
            use Funx.Ord.Dsl
            alias Funx.Optics.Prism
            alias Funx.Ord.Utils

            ord do
              asc Prism.key(:score), or_else: 0
            end
          end
        )

      # Verify it works with nil values
      alice = %{name: "Alice", score: 100}
      bob = %{name: "Bob", score: nil}

      assert Utils.compare(bob, alice, result) == :lt
    end

    test "rejects or_else with captured function projection" do
      assert_raise CompileError, ~r/cannot be used with captured functions/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord.Dsl

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
            use Funx.Ord.Dsl
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
            use Funx.Ord.Dsl
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
            use Funx.Ord.Dsl

            ord do
              asc NameLength, or_else: 0
            end
          end
        )
      end
    end

    test "rejects or_else with anonymous function" do
      assert_raise CompileError, ~r/cannot be used with anonymous functions/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Ord.Dsl

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
            use Funx.Ord.Dsl
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
            use Funx.Ord.Dsl

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
        Utils.compare(person_with_address, person_without_address, ord_city)
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
        Utils.compare(person_with_address, person_without_address, ord_city)
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
        Utils.compare(person1, person2, ord_bio_length)
      end
    end

    test "custom Ord implementation raises on invalid values" do
      person_with_address = fixture(:alice_with_address)
      person_with_nil_address = %Person{name: "Bob", address: nil}

      ord_by_address =
        ord do
          asc :address
        end

      assert_raise KeyError, fn ->
        Utils.compare(person_with_address, person_with_nil_address, ord_by_address)
      end
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

      assert Utils.compare(alice, bob, ord_empty) == :eq
      assert Utils.compare(bob, alice, ord_empty) == :eq
      assert Utils.compare(alice, alice, ord_empty) == :eq
    end

    test "equal values on projection field return :eq" do
      alice1 = %Person{name: "Alice", age: 30}
      alice2 = %Person{name: "Alice", age: 25}

      ord_name =
        ord do
          asc :name
        end

      assert Utils.compare(alice1, alice2, ord_name) == :eq
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

      sorted = Enum.sort(people, Utils.comparator(ord_name_then_age))

      assert [
               %Person{name: "Alice", age: 25},
               %Person{name: "Alice", age: 30},
               %Person{name: "Bob", age: 25},
               %Person{name: "Bob", age: 30}
             ] = sorted
    end
  end

  # ============================================================================
  # Ergonomics Comparison Tests
  # ============================================================================

  describe "ergonomics comparison" do
    test "simple case shows improved readability" do
      alice = fixture(:alice)
      bob = fixture(:bob)

      ord_person =
        ord do
          asc :name
          desc :age
        end

      assert Utils.compare(alice, bob, ord_person) == :lt
    end

    test "complex case demonstrates DSL benefits" do
      alice = %Person{name: "Alice", age: 30, score: 100, bio: "Engineer"}
      bob = %Person{name: "Bob", age: 25, score: nil, bio: "Developer"}

      ord_person =
        ord do
          asc :name
          desc :age
          asc :score, or_else: 0
          asc &String.length(&1.bio)
        end

      sorted = Enum.sort([bob, alice], Utils.comparator(ord_person))
      assert [%Person{name: "Alice"}, %Person{name: "Bob"}] = sorted
    end
  end

  # ============================================================================
  # Bare Struct Module for Type Filtering
  # ============================================================================

  describe "bare struct module as type filter" do
    defmodule Check do
      defstruct [:name, :routing_number, :account_number, :amount]
    end

    defmodule CreditCard do
      defstruct [:name, :number, :expiry, :amount]
    end

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
end
