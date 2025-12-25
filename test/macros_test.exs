defmodule Funx.MacrosTest do
  @moduledoc false
  # Comprehensive test suite for Funx.Macros
  #
  # Test Organization:
  #   - eq_for/2 macro - equality comparison based on a field
  #   - ord_for/2 macro - ordering comparison with various projection types:
  #     * Atom projections (auto-converts to Prism)
  #     * Explicit Lens projections (total access)
  #     * Explicit Prism projections (partial access)
  #     * {Prism, default} tuples (partial with fallback)
  #     * Function projections (captured and anonymous)
  #     * Struct literal projections (custom Lens/Prism)
  #     * Helper function projections (local and remote)
  #     * or_else option (with atoms and Prisms)
  #   - Compile-time error validation (or_else misuse)

  use ExUnit.Case, async: true

  require Funx.Macros

  alias Funx.Eq
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Ord
  alias Funx.Test.Person

  # ============================================================================
  # Test Domain Structs
  # ============================================================================
  defmodule Product do
    @moduledoc false
    defstruct [:name, :price, :rating]

    # Atom - should use Prism.key (safe for nil values)
    Funx.Macros.ord_for(Product, :rating)
  end

  defmodule Address do
    @moduledoc false
    defstruct [:street, :city, :state, :zip]
  end

  defmodule Customer do
    @moduledoc false
    defstruct [:name, :address]

    # Lens - total access, raises on missing
    Funx.Macros.ord_for(Customer, Lens.path([:address, :city]))
  end

  defmodule Item do
    @moduledoc false
    defstruct [:name, :score]

    # Prism - partial access, Nothing < Just semantics
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

  defmodule Check do
    @moduledoc false
    defstruct [:name, :routing_number, :account_number, :amount]
  end

  defmodule CreditCard do
    @moduledoc false
    defstruct [:name, :number, :expiry, :amount]
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

  defmodule Transaction do
    @moduledoc false
    defstruct [:id, :payment]

    # Lens.path - will raise KeyError if payment type doesn't have routing_number
    Funx.Macros.ord_for(Transaction, Lens.path([:payment, :routing_number]))
  end

  defmodule Book do
    @moduledoc false
    defstruct [:title, :pages, :author]

    # Anonymous function - fn syntax
    Funx.Macros.ord_for(Book, fn book -> String.length(book.title) + book.pages end)
  end

  defmodule MagazineHelper do
    @moduledoc false
    alias Funx.Optics.Lens

    # Helper function that returns a Lens
    def title_lens, do: Lens.key(:title)
  end

  defmodule Magazine do
    @moduledoc false
    defstruct [:title, :issue]

    # Remote function call that returns a Lens
    Funx.Macros.ord_for(Magazine, MagazineHelper.title_lens())
  end

  defmodule Document do
    @moduledoc false
    defstruct [:name, :metadata]

    # Struct literal - manually constructed Lens
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

    # Explicit Lens.key - total access to a single field
    Funx.Macros.ord_for(Report, Lens.key(:priority))
  end

  defmodule Ticket do
    @moduledoc false
    defstruct [:id, :severity, :created_at]

    # Local function call - imported function without module prefix
    import Funx.Optics.Prism, only: [key: 1]
    Funx.Macros.ord_for(Ticket, key(:severity))
  end

  # or_else option test structs
  defmodule Score do
    @moduledoc false
    defstruct [:player, :points, :bonus]

    # Atom with or_else
    Funx.Macros.ord_for(Score, :points, or_else: 0)
  end

  defmodule Rating do
    @moduledoc false
    defstruct [:item, :stars, :verified]

    # Prism with or_else
    Funx.Macros.ord_for(Rating, Prism.key(:stars), or_else: 0)
  end

  # ============================================================================
  # Helper Modules
  # ============================================================================

  defmodule ProjectionHelpers do
    @moduledoc false
    # Reusable projection functions for testing

    alias Funx.Optics.Lens

    def product_rating_lens, do: Lens.key(:rating)
    def task_priority_prism, do: Prism.key(:priority)
  end

  # ============================================================================
  # Equality Tests (eq_for/2)
  # ============================================================================

  describe "eq_for/2 macro" do
    test "eq?/2 compares structs based on the specified field" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Alice", age: 25}

      assert Eq.eq?(p1, p3)
      refute Eq.eq?(p1, p2)
    end

    test "not_eq?/2 negates eq?/2" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Alice", age: 25}

      refute Eq.not_eq?(p1, p3)
      assert Eq.not_eq?(p1, p2)
    end
  end

  # ============================================================================
  # Ordering Tests (ord_for/2) - Basic Functionality
  # ============================================================================

  describe "ord_for/2 macro - basic" do
    test "lt?/2 determines if the first struct's field is less than the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 25}

      assert Ord.lt?(p1, p2)
      refute Ord.lt?(p2, p1)
    end

    test "le?/2 determines if the first struct's field is less than or equal to the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Alice", age: 25}

      assert Ord.le?(p1, p3)
      assert Ord.le?(p3, p1)
      refute Ord.le?(p2, p1)
    end

    test "gt?/2 determines if the first struct's field is greater than the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 35}

      assert Ord.gt?(p2, p1)
      refute Ord.gt?(p1, p2)
    end

    test "ge?/2 determines if the first struct's field is greater than or equal to the second's" do
      p1 = %Person{name: "Alice", age: 30}
      p2 = %Person{name: "Bob", age: 30}
      p3 = %Person{name: "Alice", age: 35}

      assert Ord.ge?(p1, p3)
      assert Ord.ge?(p2, p1)
      refute Ord.ge?(p3, p2)
    end
  end

  # ============================================================================
  # Projection Type Tests
  # ============================================================================

  describe "ord_for/2 with atom (Prism.key behavior)" do
    test "compares by field value when both have values" do
      p1 = %Product{name: "Widget", rating: 4}
      p2 = %Product{name: "Gadget", rating: 5}

      assert Ord.lt?(p1, p2)
      refute Ord.gt?(p1, p2)
    end

    test "Nothing < Just semantics: nil sorts before non-nil" do
      p1 = %Product{name: "Widget", rating: nil}
      p2 = %Product{name: "Gadget", rating: 3}

      # nil (Nothing) should be less than any value (Just)
      assert Ord.lt?(p1, p2)
      refute Ord.lt?(p2, p1)
      assert Ord.gt?(p2, p1)
    end

    test "both nil values are equal" do
      p1 = %Product{name: "Widget", rating: nil}
      p2 = %Product{name: "Gadget", rating: nil}

      assert Ord.le?(p1, p2)
      assert Ord.ge?(p1, p2)
      refute Ord.lt?(p1, p2)
      refute Ord.gt?(p1, p2)
    end

    test "sorts list correctly with mixed nil and non-nil" do
      products = [
        %Product{name: "C", rating: 5},
        %Product{name: "A", rating: nil},
        %Product{name: "B", rating: 3},
        %Product{name: "D", rating: nil}
      ]

      sorted = Enum.sort(products, &Ord.le?/2)

      # Both nil ratings should come first, then sorted by rating value
      assert Enum.map(sorted, & &1.rating) == [nil, nil, 3, 5]
    end
  end

  describe "ord_for/2 with Lens (total access)" do
    test "compares by nested field when path exists" do
      c1 = %Customer{name: "Alice", address: %Address{city: "Austin", state: "TX"}}
      c2 = %Customer{name: "Bob", address: %Address{city: "Boston", state: "MA"}}

      assert Ord.lt?(c1, c2)
      refute Ord.lt?(c2, c1)
    end

    test "raises BadMapError when intermediate value is nil" do
      c1 = %Customer{name: "Alice", address: nil}
      c2 = %Customer{name: "Bob", address: %Address{city: "Boston", state: "MA"}}

      # Lens raises BadMapError when trying to access a key on nil
      assert_raise BadMapError, fn ->
        Ord.lt?(c1, c2)
      end
    end

    test "compares nil leaf values using Elixir's < operator" do
      c1 = %Customer{name: "Alice", address: %Address{city: nil, state: "TX"}}
      c2 = %Customer{name: "Bob", address: %Address{city: "Boston", state: "MA"}}

      # Lens extracts nil successfully, then compares nil < "Boston"
      # In Elixir, nil < any string is true
      assert Ord.lt?(c1, c2)
      refute Ord.lt?(c2, c1)
    end

    test "raises KeyError with sum types when key is missing" do
      # Transaction expects :routing_number field via Lens
      # Check has :routing_number, CreditCard does not
      t1 = %Transaction{id: 1, payment: %Check{routing_number: "111000025", amount: 100}}
      t2 = %Transaction{id: 2, payment: %CreditCard{number: "4444", amount: 200}}

      # t1 can be compared (has routing_number)
      # t2 raises KeyError because CreditCard doesn't have :routing_number field
      assert_raise KeyError, fn ->
        Ord.lt?(t1, t2)
      end

      # Also fails the other way
      assert_raise KeyError, fn ->
        Ord.lt?(t2, t1)
      end
    end

    test "succeeds when sum type has the required field" do
      # Both Check structs have :routing_number
      t1 = %Transaction{id: 1, payment: %Check{routing_number: "111000025", amount: 100}}
      t2 = %Transaction{id: 2, payment: %Check{routing_number: "222000025", amount: 200}}

      # Compares by routing_number: "111000025" < "222000025"
      assert Ord.lt?(t1, t2)
      refute Ord.lt?(t2, t1)
    end
  end

  describe "ord_for/2 with Prism (partial access)" do
    test "compares Just values normally" do
      i1 = %Item{name: "Task A", score: 10}
      i2 = %Item{name: "Task B", score: 20}

      assert Ord.lt?(i1, i2)
      refute Ord.gt?(i1, i2)
    end

    test "Nothing < Just semantics with explicit Prism" do
      i1 = %Item{name: "Task A", score: nil}
      i2 = %Item{name: "Task B", score: 10}

      assert Ord.lt?(i1, i2)
      assert Ord.gt?(i2, i1)
    end

    test "Nothing == Nothing with explicit Prism" do
      i1 = %Item{name: "Task A", score: nil}
      i2 = %Item{name: "Task B", score: nil}

      refute Ord.lt?(i1, i2)
      refute Ord.gt?(i1, i2)
      assert Ord.le?(i1, i2)
      assert Ord.ge?(i1, i2)
    end
  end

  describe "ord_for/2 with {Prism, default} (partial with fallback)" do
    test "compares by value when both have values" do
      t1 = %Task{title: "Fix bug", priority: 1}
      t2 = %Task{title: "Add feature", priority: 3}

      assert Ord.lt?(t1, t2)
      refute Ord.gt?(t1, t2)
    end

    test "uses default value when field is nil" do
      t1 = %Task{title: "Fix bug", priority: nil}
      t2 = %Task{title: "Add feature", priority: 5}

      # t1's nil becomes 0 (default), t2 is 5
      assert Ord.lt?(t1, t2)
    end

    test "both nil values use default and compare equal" do
      t1 = %Task{title: "Fix bug", priority: nil}
      t2 = %Task{title: "Add feature", priority: nil}

      # Both become 0 (default)
      refute Ord.lt?(t1, t2)
      refute Ord.gt?(t1, t2)
      assert Ord.le?(t1, t2)
    end

    test "sorts with mixed nil and values using default" do
      tasks = [
        %Task{title: "C", priority: 5},
        %Task{title: "A", priority: nil},
        %Task{title: "B", priority: 3},
        %Task{title: "D", priority: nil}
      ]

      sorted = Enum.sort(tasks, &Ord.le?/2)

      # nil becomes 0, so order should be: 0, 0, 3, 5
      priorities = Enum.map(sorted, & &1.priority)
      assert priorities == [nil, nil, 3, 5]
    end
  end

  describe "ord_for/2 with function projection" do
    test "compares using projection function" do
      a1 = %Article{title: "Hi", content: "..."}
      a2 = %Article{title: "Hello World", content: "..."}

      # Compares by title length: 2 < 11
      assert Ord.lt?(a1, a2)
      refute Ord.gt?(a1, a2)
    end

    test "equal projection values compare equal" do
      a1 = %Article{title: "abc", content: "first"}
      a2 = %Article{title: "xyz", content: "second"}

      # Both titles have length 3
      refute Ord.lt?(a1, a2)
      refute Ord.gt?(a1, a2)
      assert Ord.le?(a1, a2)
      assert Ord.ge?(a1, a2)
    end

    test "sorts by projection function" do
      articles = [
        %Article{title: "Medium title", content: "..."},
        %Article{title: "A", content: "..."},
        %Article{title: "Very long title here", content: "..."}
      ]

      sorted = Enum.sort(articles, &Ord.le?/2)

      assert Enum.map(sorted, &String.length(&1.title)) == [1, 12, 20]
    end
  end

  describe "ord_for/2 with Prism.path (nested struct access)" do
    test "compares by nested struct field when path exists" do
      i1 = %Invoice{id: 1, payment: %Payment{method: "card", amount: 100}}
      i2 = %Invoice{id: 2, payment: %Payment{method: "cash", amount: 200}}

      assert Ord.lt?(i1, i2)
      refute Ord.gt?(i1, i2)
    end

    test "Nothing < Just when intermediate struct is missing" do
      i1 = %Invoice{id: 1, payment: nil}
      i2 = %Invoice{id: 2, payment: %Payment{method: "cash", amount: 200}}

      # payment is nil (Nothing) < payment exists (Just)
      assert Ord.lt?(i1, i2)
      assert Ord.gt?(i2, i1)
    end

    test "Nothing < Just when leaf field is missing" do
      i1 = %Invoice{id: 1, payment: %Payment{method: "card", amount: nil}}
      i2 = %Invoice{id: 2, payment: %Payment{method: "cash", amount: 200}}

      # amount is nil (Nothing) < amount exists (Just)
      assert Ord.lt?(i1, i2)
      assert Ord.gt?(i2, i1)
    end

    test "both Nothing values are equal" do
      i1 = %Invoice{id: 1, payment: nil}
      i2 = %Invoice{id: 2, payment: nil}

      refute Ord.lt?(i1, i2)
      refute Ord.gt?(i1, i2)
      assert Ord.le?(i1, i2)
      assert Ord.ge?(i1, i2)
    end

    test "sorts with mixed nil and non-nil nested values" do
      invoices = [
        %Invoice{id: 3, payment: %Payment{method: "cash", amount: 300}},
        %Invoice{id: 1, payment: nil},
        %Invoice{id: 2, payment: %Payment{method: "card", amount: 150}},
        %Invoice{id: 4, payment: %Payment{method: "check", amount: nil}}
      ]

      sorted = Enum.sort(invoices, &Ord.le?/2)

      # Nothing values first, then sorted by amount
      # i1: payment=nil (Nothing)
      # i4: payment.amount=nil (Nothing)
      # i2: amount=150 (Just)
      # i3: amount=300 (Just)
      assert [sorted_i1, sorted_i4, sorted_i2, sorted_i3] = sorted
      assert sorted_i1.id == 1
      assert sorted_i4.id == 4
      assert sorted_i2.id == 2
      assert sorted_i3.id == 3
    end
  end

  describe "ord_for/2 with anonymous function (fn syntax)" do
    test "compares using anonymous function projection" do
      b1 = %Book{title: "Hi", pages: 100, author: "Alice"}
      b2 = %Book{title: "Hello", pages: 50, author: "Bob"}

      # Compares by title length + pages: (2 + 100) vs (5 + 50)
      # 102 > 55
      assert Ord.gt?(b1, b2)
      refute Ord.lt?(b1, b2)
    end

    test "equal projection values compare equal" do
      b1 = %Book{title: "abc", pages: 50, author: "Alice"}
      b2 = %Book{title: "xy", pages: 51, author: "Bob"}

      # Both: title_length + pages = 3 + 50 = 53 and 2 + 51 = 53
      refute Ord.lt?(b1, b2)
      refute Ord.gt?(b1, b2)
      assert Ord.le?(b1, b2)
      assert Ord.ge?(b1, b2)
    end

    test "sorts by anonymous function" do
      books = [
        %Book{title: "Long Title", pages: 10, author: "C"},
        %Book{title: "A", pages: 100, author: "A"},
        %Book{title: "Medium", pages: 50, author: "B"}
      ]

      sorted = Enum.sort(books, &Ord.le?/2)

      # Scores: 10+10=20, 1+100=101, 6+50=56
      assert Enum.map(sorted, fn b -> String.length(b.title) + b.pages end) == [20, 56, 101]
    end
  end

  describe "ord_for/2 with generic function call (helper that returns Lens)" do
    test "compares using helper function result" do
      m1 = %Magazine{title: "Tech Weekly", issue: 42}
      m2 = %Magazine{title: "Science Monthly", issue: 10}

      # Helper returns Lens.key(:title), so compares by title
      assert Ord.gt?(m1, m2)
      refute Ord.lt?(m1, m2)
    end

    test "sorts by helper function projection" do
      magazines = [
        %Magazine{title: "Zebra", issue: 1},
        %Magazine{title: "Alpha", issue: 100},
        %Magazine{title: "Beta", issue: 50}
      ]

      sorted = Enum.sort(magazines, &Ord.le?/2)

      assert Enum.map(sorted, & &1.title) == ["Alpha", "Beta", "Zebra"]
    end
  end

  describe "ord_for/2 with struct literal (custom Lens)" do
    test "compares using custom Lens that extracts nested metadata" do
      d1 = %Document{name: "Doc1", metadata: %{priority: 5, author: "Alice"}}
      d2 = %Document{name: "Doc2", metadata: %{priority: 3, author: "Bob"}}

      # Custom lens extracts priority from metadata
      assert Ord.gt?(d1, d2)
      refute Ord.lt?(d1, d2)
    end

    test "handles missing metadata with default value" do
      d1 = %Document{name: "Doc1", metadata: nil}
      d2 = %Document{name: "Doc2", metadata: %{priority: 5}}

      # Custom lens returns 0 for missing metadata
      assert Ord.lt?(d1, d2)
      assert Ord.gt?(d2, d1)
    end

    test "handles metadata without priority field" do
      d1 = %Document{name: "Doc1", metadata: %{author: "Alice"}}
      d2 = %Document{name: "Doc2", metadata: %{priority: 5}}

      # Custom lens returns 0 when priority key is missing
      assert Ord.lt?(d1, d2)
    end

    test "sorts by custom Lens projection" do
      documents = [
        %Document{name: "C", metadata: %{priority: 3}},
        %Document{name: "A", metadata: nil},
        %Document{name: "B", metadata: %{priority: 1}},
        %Document{name: "D", metadata: %{author: "Someone"}}
      ]

      sorted = Enum.sort(documents, &Ord.le?/2)

      # Priorities: 3, 0 (nil), 1, 0 (missing priority)
      # Sorted: 0, 0, 1, 3
      priorities =
        Enum.map(sorted, fn d ->
          Map.get(d.metadata || %{}, :priority, 0)
        end)

      assert priorities == [0, 0, 1, 3]
    end
  end

  describe "ord_for/2 with Lens.key (explicit single field lens)" do
    test "compares using Lens.key for total field access" do
      r1 = %Report{title: "Q1", status: "done", priority: 1}
      r2 = %Report{title: "Q2", status: "pending", priority: 3}
      r3 = %Report{title: "Q3", status: "done", priority: 2}

      assert Ord.lt?(r1, r2)
      assert Ord.gt?(r2, r3)
      assert Ord.lt?(r1, r3)
    end

    test "raises KeyError when field is missing from struct" do
      # Create a Report with missing :priority key by using Map and converting
      # This simulates a struct that's missing the field at runtime
      r1 = %Report{title: "Valid", status: "done", priority: 1}

      # Create a map that looks like Report but is missing the priority key
      broken_map = %{__struct__: Report, title: "Invalid", status: "pending"}

      assert_raise KeyError, fn ->
        Ord.lt?(broken_map, r1)
      end
    end

    test "handles nil values in field (nil is a valid value for Lens)" do
      r1 = %Report{title: "A", status: "done", priority: nil}
      r2 = %Report{title: "B", status: "done", priority: 5}

      # Elixir term ordering: nil (atom) > 5 (number)
      assert Ord.gt?(r1, r2)
    end

    test "sorts by priority using Lens.key" do
      reports = [
        %Report{title: "C", status: "done", priority: 3},
        %Report{title: "A", status: "pending", priority: 1},
        %Report{title: "B", status: "done", priority: 2}
      ]

      sorted = Enum.sort(reports, &Ord.le?/2)

      assert Enum.map(sorted, & &1.priority) == [1, 2, 3]
      assert Enum.map(sorted, & &1.title) == ["A", "B", "C"]
    end
  end

  describe "ord_for/2 with local function call (imported function)" do
    test "compares using imported function called without module prefix" do
      t1 = %Ticket{id: 1, severity: :low, created_at: ~N[2024-01-01 10:00:00]}
      t2 = %Ticket{id: 2, severity: :high, created_at: ~N[2024-01-02 10:00:00]}
      t3 = %Ticket{id: 3, severity: :medium, created_at: ~N[2024-01-03 10:00:00]}

      # Atom ordering: :high < :low < :medium
      assert Ord.lt?(t2, t1)
      assert Ord.lt?(t1, t3)
      assert Ord.lt?(t2, t3)
    end

    test "handles nil values with Maybe semantics (Nothing < Just)" do
      t1 = %Ticket{id: 1, severity: nil, created_at: ~N[2024-01-01 10:00:00]}
      t2 = %Ticket{id: 2, severity: :low, created_at: ~N[2024-01-02 10:00:00]}

      # Prism gives Nothing < Just semantics
      assert Ord.lt?(t1, t2)
    end

    test "sorts tickets by severity using imported key/1" do
      tickets = [
        %Ticket{id: 1, severity: :medium, created_at: ~N[2024-01-01 10:00:00]},
        %Ticket{id: 2, severity: nil, created_at: ~N[2024-01-02 10:00:00]},
        %Ticket{id: 3, severity: :low, created_at: ~N[2024-01-03 10:00:00]},
        %Ticket{id: 4, severity: :high, created_at: ~N[2024-01-04 10:00:00]}
      ]

      sorted = Enum.sort(tickets, &Ord.le?/2)

      # Nothing (nil) < :high < :low < :medium
      assert Enum.map(sorted, & &1.severity) == [nil, :high, :low, :medium]
    end
  end

  # ============================================================================
  # or_else Option Tests
  # ============================================================================

  describe "ord_for/2 with or_else option" do
    test "atom with or_else treats nil as default value" do
      s1 = %Score{player: "Alice", points: nil, bonus: 10}
      s2 = %Score{player: "Bob", points: 5, bonus: 0}
      s3 = %Score{player: "Charlie", points: 0, bonus: 5}

      # nil becomes 0, so s1 and s3 are equal at 0
      assert Ord.le?(s1, s3) and Ord.ge?(s1, s3)
      assert Ord.lt?(s1, s2)
      assert Ord.lt?(s3, s2)
    end

    test "Prism with or_else treats Nothing as default value" do
      r1 = %Rating{item: "A", stars: nil, verified: true}
      r2 = %Rating{item: "B", stars: 3, verified: false}
      r3 = %Rating{item: "C", stars: 0, verified: true}

      # nil becomes 0, so r1 and r3 are equal
      assert Ord.le?(r1, r3) and Ord.ge?(r1, r3)
      assert Ord.lt?(r1, r2)
    end

    test "sorts using or_else default for nil values" do
      scores = [
        %Score{player: "Alice", points: 10, bonus: 0},
        %Score{player: "Bob", points: nil, bonus: 5},
        %Score{player: "Charlie", points: 5, bonus: 10},
        %Score{player: "Dave", points: 0, bonus: 15}
      ]

      sorted = Enum.sort(scores, &Ord.le?/2)

      # nil → 0, so sorted: 0 (Dave), 0 (Bob with nil→0), 5, 10
      assert Enum.map(sorted, & &1.points) == [nil, 0, 5, 10]
    end
  end

  # ============================================================================
  # Compile-Time Error Validation
  # ============================================================================

  describe "ord_for/2 or_else validation" do
    test "raises when or_else used with Lens.key" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadLensKey do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.ord_for(BadLensKey, Lens.key(:field), or_else: 0)
        end
      end
    end

    test "raises when or_else used with Lens.path" do
      assert_raise ArgumentError, ~r/cannot be used with Lens/, fn ->
        defmodule BadLensPath do
          @moduledoc false
          defstruct [:nested]
          Funx.Macros.ord_for(BadLensPath, Lens.path([:nested, :field]), or_else: 0)
        end
      end
    end

    test "raises when or_else used with captured function" do
      assert_raise ArgumentError, ~r/cannot be used with captured functions/, fn ->
        defmodule BadCapturedFn do
          @moduledoc false
          defstruct [:value]
          Funx.Macros.ord_for(BadCapturedFn, &String.length(&1.value), or_else: 0)
        end
      end
    end

    test "raises when or_else used with anonymous function" do
      assert_raise ArgumentError, ~r/cannot be used with anonymous functions/, fn ->
        defmodule BadAnonFn do
          @moduledoc false
          defstruct [:value]
          Funx.Macros.ord_for(BadAnonFn, fn x -> x.value end, or_else: 0)
        end
      end
    end

    test "raises when or_else used with {Prism, default} tuple (redundant)" do
      assert_raise ArgumentError, ~r/Redundant or_else/, fn ->
        defmodule RedundantOrElse do
          @moduledoc false
          defstruct [:field]
          Funx.Macros.ord_for(RedundantOrElse, {Prism.key(:field), 5}, or_else: 0)
        end
      end
    end

    test "raises when or_else used with struct literal" do
      assert_raise ArgumentError, ~r/cannot be used with struct literals/, fn ->
        defmodule BadStructLiteral do
          @moduledoc false
          defstruct [:priority]

          Funx.Macros.ord_for(
            BadStructLiteral,
            %Lens{
              view: fn x -> x.priority end,
              update: fn x, v -> %{x | priority: v} end
            },
            or_else: 0
          )
        end
      end
    end
  end
end
