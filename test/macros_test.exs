defmodule Funx.MacrosTest do
  @moduledoc false
  # Comprehensive test suite for Funx.Macros
  #
  # Test Organization:
  #   - eq_for/2 and eq_for/3 macros - equality comparison
  #   - ord_for/2 and ord_for/3 macros - ordering comparison
  #   - Various projection types (Atom, Lens, Prism, Traversal, Function)
  #   - Compile-time error validation

  use ExUnit.Case, async: true
  use ExUnitProperties

  require Funx.Macros

  alias Funx.Eq
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Optics.Traversal
  alias Funx.Ord.Protocol
  alias Funx.Test.Person

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule Address do
    @moduledoc false
    defstruct [:street, :city, :state, :zip]
  end

  defmodule Product do
    @moduledoc false
    defstruct [:name, :price, :rating]

    # Atom projection - uses Prism.key (safe for nil)
    Funx.Macros.ord_for(Product, :rating)
  end

  defmodule Customer do
    @moduledoc false
    defstruct [:name, :address]

    # Lens projection - total access, raises on missing
    Funx.Macros.ord_for(Customer, Lens.path([:address, :city]))
  end

  defmodule Item do
    @moduledoc false
    defstruct [:name, :score]

    # Prism projection - partial access, Nothing < Just
    Funx.Macros.ord_for(Item, Prism.key(:score))
  end

  defmodule Task do
    @moduledoc false
    defstruct [:title, :priority]

    # {Prism, default} - partial with fallback
    Funx.Macros.ord_for(Task, {Prism.key(:priority), 0})
  end

  defmodule Article do
    @moduledoc false
    defstruct [:title, :content]

    # Function projection - custom logic
    Funx.Macros.ord_for(Article, &String.length(&1.title))
  end

  defmodule Payment do
    @moduledoc false
    defstruct [:method, :amount]
  end

  defmodule Invoice do
    @moduledoc false
    defstruct [:id, :payment]

    # Prism.path - nested struct access
    Funx.Macros.ord_for(Invoice, Prism.path([{Invoice, :payment}, {Payment, :amount}]))
  end

  defmodule Check do
    @moduledoc false
    defstruct [:name, :routing_number, :account_number, :amount]
  end

  defmodule CreditCard do
    @moduledoc false
    defstruct [:name, :number, :expiry, :amount]
  end

  defmodule Transaction do
    @moduledoc false
    defstruct [:id, :payment]

    # Lens.path - raises KeyError if payment doesn't have routing_number
    Funx.Macros.ord_for(Transaction, Lens.path([:payment, :routing_number]))
  end

  defmodule Book do
    @moduledoc false
    defstruct [:title, :pages, :author]

    # Anonymous function projection
    Funx.Macros.ord_for(Book, fn book -> String.length(book.title) + book.pages end)
  end

  defmodule MagazineHelper do
    @moduledoc false
    def title_lens, do: Lens.key(:title)
  end

  defmodule Magazine do
    @moduledoc false
    defstruct [:title, :issue]

    # Helper function projection
    Funx.Macros.ord_for(Magazine, MagazineHelper.title_lens())
  end

  defmodule Document do
    @moduledoc false
    defstruct [:name, :metadata]

    # Struct literal - custom Lens
    Funx.Macros.ord_for(
      Document,
      %Lens{
        view: fn doc -> Map.get(doc.metadata || %{}, :priority, 0) end,
        update: fn doc, priority ->
          %{doc | metadata: Map.put(doc.metadata || %{}, :priority, priority)}
        end
      }
    )
  end

  defmodule Report do
    @moduledoc false
    defstruct [:title, :status, :priority]

    # Explicit Lens.key
    Funx.Macros.ord_for(Report, Lens.key(:priority))
  end

  defmodule Ticket do
    @moduledoc false
    defstruct [:id, :severity, :created_at]

    # Imported function call
    import Funx.Optics.Prism, only: [key: 1]
    Funx.Macros.ord_for(Ticket, key(:severity))
  end

  defmodule Score do
    @moduledoc false
    defstruct [:player, :points, :bonus]

    # Atom with or_else option
    Funx.Macros.ord_for(Score, :points, or_else: 0)
  end

  defmodule Rating do
    @moduledoc false
    defstruct [:item, :stars, :verified]

    # Prism with or_else option
    Funx.Macros.ord_for(Rating, Prism.key(:stars), or_else: 0)
  end

  # eq_for/3 test structs
  defmodule EqProduct do
    @moduledoc false
    defstruct [:name, :price, :rating]
    Funx.Macros.eq_for(EqProduct, :rating, or_else: 0)
  end

  defmodule EqCustomer do
    @moduledoc false
    defstruct [:name, :address]
    Funx.Macros.eq_for(EqCustomer, Lens.path([:address, :city]))
  end

  defmodule EqItem do
    @moduledoc false
    defstruct [:name, :score]
    Funx.Macros.eq_for(EqItem, Prism.key(:score))
  end

  defmodule EqArticle do
    @moduledoc false
    defstruct [:title, :content]
    Funx.Macros.eq_for(EqArticle, &String.length(&1.title))
  end

  defmodule CaseInsensitiveEq do
    @moduledoc false
    def eq?(a, b), do: String.downcase(a) == String.downcase(b)
    def not_eq?(a, b), do: !eq?(a, b)
  end

  defmodule EqPerson do
    @moduledoc false
    defstruct [:name, :age]
    Funx.Macros.eq_for(EqPerson, :name, eq: CaseInsensitiveEq)
  end

  defmodule EqRecord do
    @moduledoc false
    defstruct [:name, :age, :score]
    Funx.Macros.eq_for(EqRecord, Traversal.combine([Lens.key(:name), Lens.key(:age)]))
  end

  # ============================================================================
  # DSL-based Test Structs
  # ============================================================================

  defmodule DslEqPerson do
    @moduledoc false
    use Funx.Eq

    defstruct [:name, :age, :email]

    # Complex equality: match on both name and age (inline DSL)
    Funx.Macros.eq_for(
      DslEqPerson,
      eq do
        on :name
        on :age
      end
    )
  end

  defmodule DslOrdProduct do
    @moduledoc false
    use Funx.Ord

    defstruct [:name, :price, :rating]

    # Complex ordering: first by rating desc, then by name asc (inline DSL)
    Funx.Macros.ord_for(
      DslOrdProduct,
      ord do
        desc :rating
        asc :name
      end
    )
  end

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp product_fixture(name \\ "Widget", rating \\ 5) do
    %Product{name: name, price: 10.0, rating: rating}
  end

  defp customer_fixture(name \\ "Alice", city \\ "Austin") do
    %Customer{name: name, address: %Address{city: city, state: "TX", street: "Main St"}}
  end

  defp item_fixture(name \\ "Item", score \\ 100) do
    %Item{name: name, score: score}
  end

  defp task_fixture(title \\ "Task", priority \\ 1) do
    %Task{title: title, priority: priority}
  end

  defp invoice_fixture(id \\ 1, amount \\ 100) do
    %Invoice{id: id, payment: %Payment{method: "card", amount: amount}}
  end

  defp score_fixture(player \\ "Player", points \\ 100) do
    %Score{player: player, points: points, bonus: 0}
  end

  # ============================================================================
  # Equality Tests (eq_for/2)
  # ============================================================================

  describe "eq_for/2 - backward compatibility" do
    test "eq?/2 compares structs based on specified field" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Alice", age: 25}

      assert Eq.eq?(p1, p3)
      refute Eq.eq?(p1, p2)
    end

    test "not_eq?/2 negates eq?/2" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}

      assert Eq.not_eq?(p1, p2)
      refute Eq.not_eq?(p1, p1)
    end
  end

  # ============================================================================
  # Equality Tests (eq_for/3)
  # ============================================================================

  describe "eq_for/3 with or_else option" do
    test "treats nil as default value" do
      p1 = %EqProduct{name: "A", rating: nil}
      p2 = %EqProduct{name: "B", rating: 0}
      p3 = %EqProduct{name: "C", rating: 5}

      assert Eq.eq?(p1, p2)
      refute Eq.eq?(p1, p3)
    end

    test "both nil values are equal" do
      p1 = %EqProduct{name: "A", rating: nil}
      p2 = %EqProduct{name: "B", rating: nil}

      assert Eq.eq?(p1, p2)
    end

    test "same non-nil values are equal" do
      p1 = %EqProduct{name: "A", rating: 5}
      p2 = %EqProduct{name: "B", rating: 5}

      assert Eq.eq?(p1, p2)
    end
  end

  describe "eq_for/3 with Lens projection" do
    test "compares by nested field" do
      c1 = %EqCustomer{name: "Alice", address: %Address{city: "Austin", state: "TX"}}
      c2 = %EqCustomer{name: "Bob", address: %Address{city: "Austin", state: "MA"}}
      c3 = %EqCustomer{name: "Charlie", address: %Address{city: "Boston", state: "TX"}}

      assert Eq.eq?(c1, c2)
      refute Eq.eq?(c1, c3)
    end

    test "raises BadMapError when intermediate value is nil" do
      c1 = %EqCustomer{name: "Alice", address: nil}
      c2 = %EqCustomer{name: "Bob", address: %Address{city: "Boston", state: "MA"}}

      assert_raise BadMapError, fn ->
        Eq.eq?(c1, c2)
      end
    end
  end

  describe "eq_for/3 with Prism projection" do
    test "compares Just values normally" do
      i1 = %EqItem{name: "A", score: 10}
      i2 = %EqItem{name: "B", score: 10}
      i3 = %EqItem{name: "C", score: 20}

      assert Eq.eq?(i1, i2)
      refute Eq.eq?(i1, i3)
    end

    test "Nothing == Nothing" do
      i1 = %EqItem{name: "A", score: nil}
      i2 = %EqItem{name: "B", score: nil}

      assert Eq.eq?(i1, i2)
    end

    test "Nothing != Just" do
      i1 = %EqItem{name: "A", score: nil}
      i2 = %EqItem{name: "B", score: 10}

      refute Eq.eq?(i1, i2)
    end
  end

  describe "eq_for/3 with function projection" do
    test "compares using projection function" do
      a1 = %EqArticle{title: "Hi", content: "..."}
      a2 = %EqArticle{title: "By", content: "different"}
      a3 = %EqArticle{title: "Hello", content: "..."}

      # Same title length (2)
      assert Eq.eq?(a1, a2)
      # Different title length
      refute Eq.eq?(a1, a3)
    end
  end

  describe "eq_for/3 with custom eq option" do
    test "uses custom Eq module for comparison" do
      p1 = %EqPerson{name: "Alice", age: 30}
      p2 = %EqPerson{name: "ALICE", age: 25}
      p3 = %EqPerson{name: "Bob", age: 30}

      assert Eq.eq?(p1, p2)
      refute Eq.eq?(p1, p3)
    end

    test "not_eq? uses custom Eq module" do
      p1 = %EqPerson{name: "Alice", age: 30}
      p2 = %EqPerson{name: "alice", age: 25}

      refute Eq.not_eq?(p1, p2)
    end
  end

  describe "eq_for/3 with Traversal projection" do
    test "all foci must match for equality" do
      r1 = %EqRecord{name: "Alice", age: 30, score: 100}
      r2 = %EqRecord{name: "Alice", age: 30, score: 50}
      r3 = %EqRecord{name: "Bob", age: 30, score: 100}

      assert Eq.eq?(r1, r2)
      refute Eq.eq?(r1, r3)
    end

    test "inequality when any focus differs" do
      r1 = %EqRecord{name: "Alice", age: 30, score: 100}
      r2 = %EqRecord{name: "Alice", age: 25, score: 100}

      refute Eq.eq?(r1, r2)
    end
  end

  # ============================================================================
  # Equality Validation Tests
  # ============================================================================

  describe "eq_for/3 - or_else validation" do
    test "rejects or_else with Lens.key" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadEqLensKey do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.eq_for(BadEqLensKey, Lens.key(:field), or_else: 0)
        end
      end
    end

    test "rejects or_else with Lens.path" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadEqLensPath do
          @moduledoc false
          defstruct [:nested]
          Funx.Macros.eq_for(BadEqLensPath, Lens.path([:nested, :field]), or_else: 0)
        end
      end
    end

    test "rejects or_else with captured function" do
      assert_raise ArgumentError, ~r/cannot be used with captured functions/, fn ->
        defmodule BadEqCapturedFn do
          @moduledoc false
          defstruct [:value]
          Funx.Macros.eq_for(BadEqCapturedFn, &String.length(&1.value), or_else: 0)
        end
      end
    end

    test "rejects redundant or_else with {Prism, default}" do
      assert_raise ArgumentError, ~r/Redundant or_else/, fn ->
        defmodule RedundantEqOrElse do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.eq_for(RedundantEqOrElse, {Prism.key(:field), 5}, or_else: 0)
        end
      end
    end

    test "rejects or_else with Traversal" do
      assert_raise ArgumentError, ~r/cannot be used with Traversal/, fn ->
        defmodule BadEqTraversal do
          @moduledoc false
          defstruct [:name, :age]

          Funx.Macros.eq_for(
            BadEqTraversal,
            Traversal.combine([Lens.key(:name)]),
            or_else: "unknown"
          )
        end
      end
    end
  end

  # ============================================================================
  # DSL Tests (eq_for with Eq DSL, ord_for with Ord DSL)
  # ============================================================================

  describe "eq_for with Eq DSL" do
    test "eq?/2 uses DSL-defined equality (both fields must match)" do
      p1 = %DslEqPerson{name: "Alice", age: 30, email: "alice@example.com"}
      p2 = %DslEqPerson{name: "Alice", age: 30, email: "different@example.com"}
      p3 = %DslEqPerson{name: "Alice", age: 25, email: "alice@example.com"}
      p4 = %DslEqPerson{name: "Bob", age: 30, email: "alice@example.com"}

      # Same name and age, different email - should be equal (DSL only checks name and age)
      assert Eq.eq?(p1, p2)

      # Same name, different age - should not be equal
      refute Eq.eq?(p1, p3)

      # Different name, same age - should not be equal
      refute Eq.eq?(p1, p4)
    end

    test "not_eq?/2 negates DSL-defined equality" do
      p1 = %DslEqPerson{name: "Alice", age: 30, email: "a@test.com"}
      p2 = %DslEqPerson{name: "Alice", age: 30, email: "b@test.com"}
      p3 = %DslEqPerson{name: "Bob", age: 30, email: "a@test.com"}

      refute Eq.not_eq?(p1, p2)
      assert Eq.not_eq?(p1, p3)
    end
  end

  describe "ord_for with Ord DSL" do
    test "compares using DSL-defined ordering (desc rating, then asc name)" do
      # Higher rating should come first (desc), so prod1 is "less than" prod2 in sort order
      prod1 = %DslOrdProduct{name: "Widget", price: 10, rating: 5}
      prod2 = %DslOrdProduct{name: "Gadget", price: 20, rating: 3}

      # In desc rating order: rating 5 comes before rating 3
      assert Protocol.lt?(prod1, prod2)
      assert Protocol.gt?(prod2, prod1)
    end

    test "uses secondary sort key when primary is equal" do
      # Same rating, should sort by name (asc)
      prod1 = %DslOrdProduct{name: "Apple", price: 10, rating: 5}
      prod2 = %DslOrdProduct{name: "Banana", price: 20, rating: 5}

      assert Protocol.lt?(prod1, prod2)
      assert Protocol.gt?(prod2, prod1)
    end

    test "sorts list correctly with DSL ordering" do
      products = [
        %DslOrdProduct{name: "Zebra", price: 10, rating: 3},
        %DslOrdProduct{name: "Apple", price: 20, rating: 5},
        %DslOrdProduct{name: "Banana", price: 15, rating: 5},
        %DslOrdProduct{name: "Cherry", price: 25, rating: 3}
      ]

      sorted = Enum.sort(products, &Protocol.le?/2)

      # Should be: rating 5 first (Apple, Banana by name), then rating 3 (Cherry, Zebra by name)
      assert Enum.map(sorted, & &1.name) == ["Apple", "Banana", "Cherry", "Zebra"]
    end
  end

  # ============================================================================
  # DSL via Function Call Tests (ord_for/eq_for with function returning DSL result)
  # ============================================================================

  # Helper module for defining ord/eq functions
  defmodule OrdEqHelpers do
    @moduledoc false
    use Funx.Ord
    use Funx.Eq

    alias Funx.Optics.Lens

    def card_ord do
      ord do
        asc Lens.key(:color)
        asc Lens.key(:value)
      end
    end

    def person_eq do
      eq do
        on :name
        on :age
      end
    end

    def reverse_priority_ord do
      ord do
        desc :priority
        asc :title
      end
    end
  end

  defmodule FnOrdCard do
    @moduledoc false
    defstruct [:color, :value, :suit]

    # Using function call that returns an Ord map from DSL
    Funx.Macros.ord_for(FnOrdCard, OrdEqHelpers.card_ord())
  end

  defmodule FnEqEmployee do
    @moduledoc false
    defstruct [:name, :age, :department]

    # Using function call that returns an Eq map from DSL
    Funx.Macros.eq_for(FnEqEmployee, OrdEqHelpers.person_eq())
  end

  defmodule FnOrdTask do
    @moduledoc false
    defstruct [:title, :priority, :status]

    # Using function call with desc ordering
    Funx.Macros.ord_for(FnOrdTask, OrdEqHelpers.reverse_priority_ord())
  end

  describe "ord_for with function returning Ord DSL result" do
    test "compares using DSL from function call" do
      card1 = %FnOrdCard{color: :red, value: 5, suit: :hearts}
      card2 = %FnOrdCard{color: :red, value: 10, suit: :diamonds}
      card3 = %FnOrdCard{color: :blue, value: 1, suit: :clubs}

      # Same color, different value: 5 < 10
      assert Protocol.lt?(card1, card2)

      # Different color: :blue < :red (atom ordering)
      assert Protocol.lt?(card3, card1)
    end

    test "uses secondary sort key from function-returned DSL" do
      card1 = %FnOrdCard{color: :red, value: 5, suit: :hearts}
      card2 = %FnOrdCard{color: :red, value: 5, suit: :diamonds}

      # Same color and value - should be equal
      assert Protocol.le?(card1, card2)
      assert Protocol.ge?(card1, card2)
    end

    test "sorts list using function-returned DSL ordering" do
      cards = [
        %FnOrdCard{color: :red, value: 10, suit: :hearts},
        %FnOrdCard{color: :blue, value: 5, suit: :clubs},
        %FnOrdCard{color: :red, value: 3, suit: :diamonds},
        %FnOrdCard{color: :blue, value: 8, suit: :spades}
      ]

      sorted = Enum.sort(cards, &Protocol.le?/2)

      # First by color (:blue < :red), then by value
      assert Enum.map(sorted, &{&1.color, &1.value}) == [
               {:blue, 5},
               {:blue, 8},
               {:red, 3},
               {:red, 10}
             ]
    end

    test "desc ordering from function-returned DSL" do
      task1 = %FnOrdTask{title: "A", priority: 1, status: :pending}
      task2 = %FnOrdTask{title: "B", priority: 5, status: :done}

      # Higher priority should come first (desc), so task2 < task1 in sort order
      assert Protocol.lt?(task2, task1)
      assert Protocol.gt?(task1, task2)
    end

    test "secondary asc sort with desc primary from function" do
      task1 = %FnOrdTask{title: "Zebra", priority: 3, status: :pending}
      task2 = %FnOrdTask{title: "Alpha", priority: 3, status: :done}

      # Same priority, sort by title asc: Alpha < Zebra
      assert Protocol.lt?(task2, task1)
    end
  end

  describe "eq_for with function returning Eq DSL result" do
    test "compares using DSL from function call" do
      emp1 = %FnEqEmployee{name: "Alice", age: 30, department: "Engineering"}
      emp2 = %FnEqEmployee{name: "Alice", age: 30, department: "Marketing"}
      emp3 = %FnEqEmployee{name: "Bob", age: 30, department: "Engineering"}

      # Same name and age, different department - equal (DSL only checks name and age)
      assert Eq.eq?(emp1, emp2)

      # Different name - not equal
      refute Eq.eq?(emp1, emp3)
    end

    test "not_eq? works with function-returned DSL" do
      emp1 = %FnEqEmployee{name: "Alice", age: 30, department: "Eng"}
      emp2 = %FnEqEmployee{name: "Alice", age: 25, department: "Eng"}

      # Different age - not equal
      assert Eq.not_eq?(emp1, emp2)
    end

    test "reflexivity with function-returned DSL" do
      emp = %FnEqEmployee{name: "Test", age: 42, department: "QA"}

      assert Eq.eq?(emp, emp)
      refute Eq.not_eq?(emp, emp)
    end
  end

  # ============================================================================
  # Ordering Tests (ord_for/2) - Basic Operations
  # ============================================================================

  describe "ord_for/2 - basic operations" do
    test "lt?/2 compares first value less than second" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 25}

      assert Protocol.lt?(p1, p2)
      refute Protocol.lt?(p2, p1)
    end

    test "le?/2 compares first value less than or equal to second" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Alice", age: 25}

      assert Protocol.le?(p1, p2)
      assert Protocol.le?(p2, p1)
    end

    test "gt?/2 compares first value greater than second" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 35}

      assert Protocol.gt?(p2, p1)
      refute Protocol.gt?(p1, p2)
    end

    test "ge?/2 compares first value greater than or equal to second" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Alice", age: 35}

      assert Protocol.ge?(p1, p2)
      assert Protocol.ge?(p2, p1)
    end
  end

  # ============================================================================
  # Ordering Tests - Projection Types
  # ============================================================================

  describe "ord_for/2 with atom projection (Prism.key semantics)" do
    test "compares by field value when both present" do
      p1 = product_fixture("Widget", 4)
      p2 = product_fixture()

      assert Protocol.lt?(p1, p2)
      refute Protocol.gt?(p1, p2)
    end

    test "Nothing < Just: nil sorts before non-nil" do
      p1 = %Product{name: "Widget", rating: nil}
      p2 = product_fixture("Gadget", 3)

      assert Protocol.lt?(p1, p2)
      assert Protocol.gt?(p2, p1)
    end

    test "Nothing == Nothing: both nil are equal" do
      p1 = %Product{name: "Widget", rating: nil}
      p2 = %Product{name: "Gadget", rating: nil}

      refute Protocol.lt?(p1, p2)
      refute Protocol.gt?(p1, p2)
      assert Protocol.le?(p1, p2)
      assert Protocol.ge?(p1, p2)
    end

    test "sorts list with mixed nil and non-nil values" do
      products = [
        product_fixture(),
        %Product{name: "A", rating: nil},
        product_fixture("B", 3),
        %Product{name: "D", rating: nil}
      ]

      sorted = Enum.sort(products, &Protocol.le?/2)

      assert Enum.map(sorted, & &1.rating) == [nil, nil, 3, 5]
    end
  end

  describe "ord_for/2 with Lens projection (total access)" do
    test "compares by nested field when path exists" do
      c1 = customer_fixture("Alice", "Austin")
      c2 = customer_fixture("Bob", "Boston")

      assert Protocol.lt?(c1, c2)
      refute Protocol.lt?(c2, c1)
    end

    test "raises BadMapError when intermediate value is nil" do
      c1 = %Customer{name: "Alice", address: nil}
      c2 = customer_fixture()

      assert_raise BadMapError, fn ->
        Protocol.lt?(c1, c2)
      end
    end

    test "handles nil leaf values using Elixir term ordering" do
      c1 = %Customer{name: "Alice", address: %Address{city: nil, state: "TX"}}
      c2 = customer_fixture()

      # In Elixir, nil < string
      assert Protocol.lt?(c1, c2)
    end

    test "raises KeyError with sum types when field missing" do
      t1 = %Transaction{id: 1, payment: %Check{routing_number: "111000025"}}
      t2 = %Transaction{id: 2, payment: %CreditCard{number: "4444"}}

      assert_raise KeyError, fn ->
        Protocol.lt?(t1, t2)
      end
    end

    test "succeeds when sum type has required field" do
      t1 = %Transaction{id: 1, payment: %Check{routing_number: "111000025"}}
      t2 = %Transaction{id: 2, payment: %Check{routing_number: "222000025"}}

      assert Protocol.lt?(t1, t2)
    end
  end

  describe "ord_for/2 with Prism projection (partial access)" do
    test "compares Just values normally" do
      i1 = item_fixture("A", 10)
      i2 = item_fixture()

      assert Protocol.lt?(i1, i2)
      refute Protocol.gt?(i1, i2)
    end

    test "Nothing < Just with explicit Prism" do
      i1 = %Item{name: "A", score: nil}
      i2 = item_fixture()

      assert Protocol.lt?(i1, i2)
      assert Protocol.gt?(i2, i1)
    end

    test "Nothing == Nothing with explicit Prism" do
      i1 = %Item{name: "A", score: nil}
      i2 = %Item{name: "B", score: nil}

      refute Protocol.lt?(i1, i2)
      refute Protocol.gt?(i1, i2)
      assert Protocol.le?(i1, i2)
    end
  end

  describe "ord_for/2 with {Prism, default} (partial with fallback)" do
    test "compares values when both present" do
      t1 = task_fixture()
      t2 = task_fixture("Feature", 3)

      assert Protocol.lt?(t1, t2)
    end

    test "uses default when field is nil" do
      t1 = %Task{title: "Bug", priority: nil}
      t2 = task_fixture()

      # nil becomes 0 (default)
      assert Protocol.lt?(t1, t2)
    end

    test "both nil values use default" do
      t1 = %Task{title: "Bug", priority: nil}
      t2 = %Task{title: "Feature", priority: nil}

      refute Protocol.lt?(t1, t2)
      assert Protocol.le?(t1, t2)
    end

    test "sorts with mixed nil and values" do
      tasks = [
        task_fixture("C", 5),
        %Task{title: "A", priority: nil},
        task_fixture("B", 3)
      ]

      sorted = Enum.sort(tasks, &Protocol.le?/2)
      priorities = Enum.map(sorted, & &1.priority)

      # nil becomes 0: [0, 3, 5]
      assert priorities == [nil, 3, 5]
    end
  end

  describe "ord_for/2 with function projection" do
    test "compares using projection function" do
      a1 = %Article{title: "Hi", content: "..."}
      a2 = %Article{title: "Hello World", content: "..."}

      # Compares by title length: 2 < 11
      assert Protocol.lt?(a1, a2)
    end

    test "equal projection values are equal" do
      a1 = %Article{title: "abc", content: "first"}
      a2 = %Article{title: "xyz", content: "second"}

      # Both have length 3
      assert Protocol.le?(a1, a2)
      assert Protocol.ge?(a1, a2)
    end

    test "sorts by projection" do
      articles = [
        %Article{title: "Medium title", content: "..."},
        %Article{title: "A", content: "..."},
        %Article{title: "Very long title here", content: "..."}
      ]

      sorted = Enum.sort(articles, &Protocol.le?/2)

      assert Enum.map(sorted, &String.length(&1.title)) == [1, 12, 20]
    end
  end

  describe "ord_for/2 with Prism.path (nested struct access)" do
    test "compares by nested field when path exists" do
      i1 = invoice_fixture()
      i2 = invoice_fixture(2, 200)

      assert Protocol.lt?(i1, i2)
    end

    test "Nothing < Just when intermediate struct missing" do
      i1 = %Invoice{id: 1, payment: nil}
      i2 = invoice_fixture()

      assert Protocol.lt?(i1, i2)
    end

    test "Nothing < Just when leaf field missing" do
      i1 = %Invoice{id: 1, payment: %Payment{method: "card", amount: nil}}
      i2 = invoice_fixture(2, 200)

      assert Protocol.lt?(i1, i2)
    end

    test "both Nothing values are equal" do
      i1 = %Invoice{id: 1, payment: nil}
      i2 = %Invoice{id: 2, payment: nil}

      refute Protocol.lt?(i1, i2)
      assert Protocol.le?(i1, i2)
    end

    test "sorts with mixed nil and non-nil nested values" do
      invoices = [
        invoice_fixture(3, 300),
        %Invoice{id: 1, payment: nil},
        invoice_fixture(2, 150),
        %Invoice{id: 4, payment: %Payment{amount: nil}}
      ]

      sorted = Enum.sort(invoices, &Protocol.le?/2)

      # Nothing values first, then sorted by amount
      assert [i1, i4, i2, i3] = sorted
      assert i1.id == 1
      assert i4.id == 4
      assert i2.id == 2
      assert i3.id == 3
    end
  end

  describe "ord_for/2 with anonymous function" do
    test "compares using anonymous function" do
      b1 = %Book{title: "Hi", pages: 100, author: "Alice"}
      b2 = %Book{title: "Hello", pages: 50, author: "Bob"}

      # title_length + pages: 102 vs 55
      assert Protocol.gt?(b1, b2)
    end

    test "equal projections are equal" do
      b1 = %Book{title: "abc", pages: 50, author: "Alice"}
      b2 = %Book{title: "xy", pages: 51, author: "Bob"}

      # Both: 3+50=53 and 2+51=53
      assert Protocol.le?(b1, b2)
      assert Protocol.ge?(b1, b2)
    end
  end

  describe "ord_for/2 with helper function" do
    test "compares using helper function result" do
      m1 = %Magazine{title: "Tech Weekly", issue: 42}
      m2 = %Magazine{title: "Science Monthly", issue: 10}

      assert Protocol.gt?(m1, m2)
    end

    test "sorts by helper projection" do
      magazines = [
        %Magazine{title: "Zebra", issue: 1},
        %Magazine{title: "Alpha", issue: 100},
        %Magazine{title: "Beta", issue: 50}
      ]

      sorted = Enum.sort(magazines, &Protocol.le?/2)

      assert Enum.map(sorted, & &1.title) == ["Alpha", "Beta", "Zebra"]
    end
  end

  describe "ord_for/2 with struct literal (custom Lens)" do
    test "compares using custom Lens" do
      d1 = %Document{name: "Doc1", metadata: %{priority: 5}}
      d2 = %Document{name: "Doc2", metadata: %{priority: 3}}

      assert Protocol.gt?(d1, d2)
    end

    test "handles missing metadata with default" do
      d1 = %Document{name: "Doc1", metadata: nil}
      d2 = %Document{name: "Doc2", metadata: %{priority: 5}}

      assert Protocol.lt?(d1, d2)
    end

    test "handles metadata without priority field" do
      d1 = %Document{name: "Doc1", metadata: %{author: "Alice"}}
      d2 = %Document{name: "Doc2", metadata: %{priority: 5}}

      assert Protocol.lt?(d1, d2)
    end
  end

  describe "ord_for/2 with Lens.key" do
    test "compares using Lens.key" do
      r1 = %Report{title: "Q1", priority: 1}
      r2 = %Report{title: "Q2", priority: 3}

      assert Protocol.lt?(r1, r2)
    end

    test "raises KeyError when field missing" do
      r1 = %Report{title: "Valid", priority: 1}
      broken = %{__struct__: Report, title: "Invalid"}

      assert_raise KeyError, fn ->
        Protocol.lt?(broken, r1)
      end
    end

    test "handles nil values (Elixir term ordering)" do
      r1 = %Report{title: "A", priority: nil}
      r2 = %Report{title: "B", priority: 5}

      # In Elixir, nil > number
      assert Protocol.gt?(r1, r2)
    end
  end

  describe "ord_for/2 with imported function" do
    test "compares using imported function" do
      t1 = %Ticket{id: 1, severity: :low}
      t2 = %Ticket{id: 2, severity: :high}

      # Atom ordering: :high < :low
      assert Protocol.lt?(t2, t1)
    end

    test "handles nil with Maybe semantics" do
      t1 = %Ticket{id: 1, severity: nil}
      t2 = %Ticket{id: 2, severity: :low}

      assert Protocol.lt?(t1, t2)
    end
  end

  # ============================================================================
  # Ordering Tests - or_else Option
  # ============================================================================

  describe "ord_for/3 with or_else option" do
    test "atom with or_else treats nil as default" do
      s1 = %Score{player: "Alice", points: nil}
      s2 = score_fixture()
      s3 = score_fixture("Charlie", 0)

      # nil becomes 0
      assert Protocol.le?(s1, s3)
      assert Protocol.ge?(s1, s3)
      assert Protocol.lt?(s1, s2)
    end

    test "Prism with or_else treats Nothing as default" do
      r1 = %Rating{item: "A", stars: nil}
      r2 = %Rating{item: "B", stars: 3}
      r3 = %Rating{item: "C", stars: 0}

      # nil becomes 0
      assert Protocol.le?(r1, r3)
      assert Protocol.lt?(r1, r2)
    end

    test "sorts using or_else default" do
      scores = [
        score_fixture(),
        %Score{player: "Bob", points: nil},
        score_fixture("Charlie", 5)
      ]

      sorted = Enum.sort(scores, &Protocol.le?/2)

      # nil→0, so: 0, 5, 10
      assert Enum.map(sorted, & &1.points) == [nil, 5, 100]
    end
  end

  # ============================================================================
  # Ordering Validation Tests
  # ============================================================================

  describe "ord_for/3 - or_else validation" do
    test "rejects or_else with Lens.key" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadOrdLensKey do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.ord_for(BadOrdLensKey, Lens.key(:field), or_else: 0)
        end
      end
    end

    test "rejects or_else with Lens.path" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadOrdLensPath do
          @moduledoc false
          defstruct [:nested]
          Funx.Macros.ord_for(BadOrdLensPath, Lens.path([:nested, :field]), or_else: 0)
        end
      end
    end

    test "rejects or_else with captured function" do
      assert_raise ArgumentError, ~r/cannot be used with captured functions/, fn ->
        defmodule BadOrdCapturedFn do
          @moduledoc false
          defstruct [:value]
          Funx.Macros.ord_for(BadOrdCapturedFn, &String.length(&1.value), or_else: 0)
        end
      end
    end

    test "rejects or_else with anonymous function" do
      assert_raise ArgumentError, ~r/cannot be used with anonymous functions/, fn ->
        defmodule BadOrdAnonFn do
          @moduledoc false
          defstruct [:value]
          Funx.Macros.ord_for(BadOrdAnonFn, fn x -> x.value end, or_else: 0)
        end
      end
    end

    test "rejects redundant or_else with {Prism, default}" do
      assert_raise ArgumentError, ~r/Redundant or_else/, fn ->
        defmodule RedundantOrdOrElse do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.ord_for(RedundantOrdOrElse, {Prism.key(:field), 5}, or_else: 0)
        end
      end
    end

    test "rejects or_else with struct literal" do
      assert_raise ArgumentError, ~r/cannot be used with struct literals/, fn ->
        defmodule BadOrdStructLiteral do
          @moduledoc false
          defstruct [:priority]

          Funx.Macros.ord_for(
            BadOrdStructLiteral,
            %Lens{view: fn x -> x.priority end, update: fn x, v -> %{x | priority: v} end},
            or_else: 0
          )
        end
      end
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: Eq reflexivity" do
    property "value always equals itself" do
      check all(rating <- integer(0..5)) do
        p = %EqProduct{name: "Test", rating: rating}

        assert Eq.eq?(p, p)
      end
    end
  end

  describe "property: Eq symmetry" do
    property "if a == b then b == a" do
      check all(
              rating <- integer(0..5),
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric)
            ) do
        p1 = %EqProduct{name: name1, rating: rating}
        p2 = %EqProduct{name: name2, rating: rating}

        assert Eq.eq?(p1, p2) == Eq.eq?(p2, p1)
      end
    end
  end

  describe "property: Eq transitivity" do
    property "if a == b and b == c then a == c" do
      check all(rating <- integer(0..5)) do
        p1 = %EqProduct{name: "A", rating: rating}
        p2 = %EqProduct{name: "B", rating: rating}
        p3 = %EqProduct{name: "C", rating: rating}

        eq_ab = Eq.eq?(p1, p2)
        eq_bc = Eq.eq?(p2, p3)
        eq_ac = Eq.eq?(p1, p3)

        # If both are true, then transitivity must hold
        if eq_ab and eq_bc do
          assert eq_ac
        end
      end
    end
  end

  describe "property: Ord reflexivity" do
    property "value always le itself" do
      check all(rating <- integer(0..5)) do
        p = product_fixture("Test", rating)

        assert Protocol.le?(p, p)
        assert Protocol.ge?(p, p)
      end
    end
  end

  describe "property: Ord antisymmetry" do
    property "if a <= b and b <= a then a == b (by projection)" do
      check all(
              rating <- integer(0..5),
              name1 <- string(:alphanumeric),
              name2 <- string(:alphanumeric)
            ) do
        p1 = product_fixture(name1, rating)
        p2 = product_fixture(name2, rating)

        le_ab = Protocol.le?(p1, p2)
        le_ba = Protocol.le?(p2, p1)

        if le_ab and le_ba do
          # Both have same rating
          assert p1.rating == p2.rating
        end
      end
    end
  end

  describe "property: Ord transitivity" do
    property "if a <= b and b <= c then a <= c" do
      check all(
              r1 <- integer(0..10),
              r2 <- integer(0..10),
              r3 <- integer(0..10)
            ) do
        p1 = product_fixture("A", r1)
        p2 = product_fixture("B", r2)
        p3 = product_fixture("C", r3)

        le_ab = Protocol.le?(p1, p2)
        le_bc = Protocol.le?(p2, p3)
        le_ac = Protocol.le?(p1, p3)

        if le_ab and le_bc do
          assert le_ac
        end
      end
    end
  end

  describe "property: or_else default handling" do
    property "nil always equals default value" do
      check all(_rating <- integer(0..5)) do
        p1 = %EqProduct{name: "A", rating: nil}
        p2 = %EqProduct{name: "B", rating: 0}

        # nil becomes 0 via or_else
        assert Eq.eq?(p1, p2)
      end
    end

    property "nil always compares as default value" do
      check all(_rating <- integer(1..10)) do
        s1 = %Score{player: "A", points: nil}
        s2 = score_fixture("B", 0)
        s3 = score_fixture()

        # nil becomes 0, so s1 == s2 < s3
        assert Protocol.le?(s1, s2) and Protocol.ge?(s1, s2)
        assert Protocol.lt?(s1, s3)
      end
    end
  end
end
