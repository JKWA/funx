defmodule Funx.Eq.DslTest do
  use ExUnit.Case
  use Funx.Eq.Dsl
  alias Funx.Eq.Utils
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Optics.Traversal

  defmodule Person do
    defstruct [:name, :age, :email, :username, :score, :id]
  end

  defmodule Check, do: defstruct([:id])
  defmodule CreditCard, do: defstruct([:id])
  defmodule Address, do: defstruct([:city])
  defmodule PersonWithAddress, do: defstruct([:name, :address])

  defmodule CaseInsensitiveString do
    defstruct [:value]
  end

  defimpl Funx.Eq, for: CaseInsensitiveString do
    def eq?(a, b) do
      String.downcase(a.value) == String.downcase(b.value)
    end

    def not_eq?(a, b) do
      String.downcase(a.value) != String.downcase(b.value)
    end
  end

  # Behaviour that returns an Eq map (not a projection!)
  defmodule UserById do
    @behaviour Funx.Eq.Dsl.Behaviour

    @impl true
    def eq(_opts) do
      Utils.contramap(&(&1.id))
    end
  end

  # Behaviour with options support
  defmodule UserByName do
    @behaviour Funx.Eq.Dsl.Behaviour

    @impl true
    def eq(opts) do
      case_sensitive = Keyword.get(opts, :case_sensitive, true)

      if case_sensitive do
        Utils.contramap(&(&1.name))
      else
        Utils.contramap(fn person -> String.downcase(person.name) end)
      end
    end
  end

  defmodule ProjectionHelpers do
    alias Funx.Optics.{Lens, Prism}

    def name_prism, do: Prism.key(:name)
    def age_lens, do: Lens.key(:age)
  end

  defmodule EqHelpers do
    def name_case_insensitive do
      Utils.contramap(fn person -> String.downcase(person.name) end)
    end

    def age_mod_10 do
      Utils.contramap(fn person -> rem(person.age, 10) end)
    end
  end

  describe "basic on directive" do
    test "single field" do
      eq_name =
        eq do
          on :name
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Alice"}, eq_name)
      refute Utils.eq?(%Person{name: "Alice"}, %Person{name: "Bob"}, eq_name)
    end

    test "multiple fields (implicit all)" do
      eq_person =
        eq do
          on :name
          on :age
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 30},
               eq_person
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 25},
               eq_person
             )
    end

    test "all fields must match for equality" do
      eq_person =
        eq do
          on :name
          on :age
          on :email
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               eq_person
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 30, email: "b@test.com"},
               eq_person
             )
    end
  end

  describe "not_on directive" do
    test "fields must differ" do
      eq_same_person_diff_record =
        eq do
          on :name
          on :email
          not_on :id
        end

      assert Utils.eq?(
               %Person{name: "Alice", email: "a@test.com", id: 1},
               %Person{name: "Alice", email: "a@test.com", id: 2},
               eq_same_person_diff_record
             )

      refute Utils.eq?(
               %Person{name: "Alice", email: "a@test.com", id: 1},
               %Person{name: "Alice", email: "a@test.com", id: 1},
               eq_same_person_diff_record
             )
    end

    test "not_on with matching required fields" do
      eq_person =
        eq do
          on :name
          not_on :id
        end

      assert Utils.eq?(
               %Person{name: "Alice", id: 1},
               %Person{name: "Alice", id: 2},
               eq_person
             )

      refute Utils.eq?(
               %Person{name: "Alice", id: 1},
               %Person{name: "Bob", id: 2},
               eq_person
             )
    end
  end

  describe "or_else option" do
    test "nil treated as default" do
      eq_score =
        eq do
          on :score, or_else: 0
        end

      assert Utils.eq?(%Person{score: nil}, %Person{score: 0}, eq_score)
      assert Utils.eq?(%Person{score: 10}, %Person{score: 10}, eq_score)
      refute Utils.eq?(%Person{score: nil}, %Person{score: 10}, eq_score)
    end

    test "or_else with multiple fields" do
      eq_person =
        eq do
          on :name
          on :score, or_else: 0
        end

      assert Utils.eq?(
               %Person{name: "Alice", score: nil},
               %Person{name: "Alice", score: 0},
               eq_person
             )

      refute Utils.eq?(
               %Person{name: "Alice", score: nil},
               %Person{name: "Bob", score: 0},
               eq_person
             )
    end
  end

  describe "nested any blocks" do
    test "at least one must match" do
      eq_contact =
        eq do
          any do
            on :email
            on :username
          end
        end

      assert Utils.eq?(
               %Person{email: "a@test.com", username: "alice"},
               %Person{email: "a@test.com", username: "bob"},
               eq_contact
             )

      assert Utils.eq?(
               %Person{email: "a@test.com", username: "alice"},
               %Person{email: "b@test.com", username: "alice"},
               eq_contact
             )

      refute Utils.eq?(
               %Person{email: "a@test.com", username: "alice"},
               %Person{email: "b@test.com", username: "bob"},
               eq_contact
             )
    end

    test "mixed on and any" do
      eq_mixed =
        eq do
          on :name

          any do
            on :email
            on :username
          end
        end

      assert Utils.eq?(
               %Person{name: "Alice", email: "a@test.com", username: "alice"},
               %Person{name: "Alice", email: "a@test.com", username: "different"},
               eq_mixed
             )

      refute Utils.eq?(
               %Person{name: "Alice", email: "a@test.com"},
               %Person{name: "Bob", email: "a@test.com"},
               eq_mixed
             )
    end

    test "any with all fields different fails" do
      eq_contact =
        eq do
          any do
            on :email
            on :username
          end
        end

      refute Utils.eq?(
               %Person{email: "a@test.com", username: "alice"},
               %Person{email: "b@test.com", username: "bob"},
               eq_contact
             )
    end
  end

  describe "nested all blocks (explicit)" do
    test "explicit all nesting" do
      eq_explicit =
        eq do
          all do
            on :name
            on :age
          end

          any do
            on :email
            on :username
          end
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com", username: "alice"},
               %Person{name: "Alice", age: 30, email: "a@test.com", username: "different"},
               eq_explicit
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 25, email: "a@test.com"},
               eq_explicit
             )
    end

    test "nested all blocks" do
      eq_nested =
        eq do
          all do
            on :name

            all do
              on :age
              on :email
            end
          end
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               eq_nested
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 25, email: "a@test.com"},
               eq_nested
             )
    end
  end

  describe "deep nesting" do
    test "arbitrary depth" do
      eq_deep =
        eq do
          on :name

          any do
            on :email

            all do
              on :age
              on :username
            end
          end
        end

      assert Utils.eq?(
               %Person{name: "Alice", email: "a@test.com"},
               %Person{name: "Alice", email: "a@test.com"},
               eq_deep
             )

      assert Utils.eq?(
               %Person{name: "Alice", age: 30, username: "alice"},
               %Person{name: "Alice", age: 30, username: "alice"},
               eq_deep
             )

      refute Utils.eq?(
               %Person{name: "Alice", email: "a@test.com"},
               %Person{name: "Bob", email: "a@test.com"},
               eq_deep
             )
    end

    test "three levels deep" do
      eq_very_deep =
        eq do
          all do
            on :name

            any do
              on :email

              all do
                on :age
                on :username
              end
            end
          end
        end

      assert Utils.eq?(
               %Person{name: "Alice", email: "a@test.com"},
               %Person{name: "Alice", email: "a@test.com"},
               eq_very_deep
             )
    end
  end

  describe "projection types" do
    test "function projection" do
      eq_length =
        eq do
          on &String.length/1
        end

      assert Utils.eq?("hello", "world", eq_length)
      refute Utils.eq?("hi", "world", eq_length)
    end

    test "anonymous function projection" do
      eq_anon =
        eq do
          on fn person -> person.name end
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Alice"}, eq_anon)
      refute Utils.eq?(%Person{name: "Alice"}, %Person{name: "Bob"}, eq_anon)
    end

    test "explicit Lens" do
      eq_lens =
        eq do
          on Lens.key(:name)
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Alice"}, eq_lens)
    end

    test "Lens.path for nested access" do
      eq_city =
        eq do
          on Lens.path([:address, :city])
        end

      assert Utils.eq?(
               %PersonWithAddress{address: %Address{city: "NYC"}},
               %PersonWithAddress{address: %Address{city: "NYC"}},
               eq_city
             )
    end

    test "explicit Prism" do
      eq_prism =
        eq do
          on Prism.key(:score)
        end

      assert Utils.eq?(%Person{score: 10}, %Person{score: 10}, eq_prism)
      assert Utils.eq?(%Person{score: nil}, %Person{score: nil}, eq_prism)
    end

    test "Prism with or_else" do
      eq_prism_default =
        eq do
          on {Prism.key(:score), 0}
        end

      assert Utils.eq?(%Person{score: nil}, %Person{score: 0}, eq_prism_default)
    end

    test "mixed projection types" do
      eq_mixed =
        eq do
          on :name
          on Lens.key(:age)
          on & &1.email
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               %Person{name: "Alice", age: 30, email: "a@test.com"},
               eq_mixed
             )
    end

    test "Traversal with all foci present and matching" do
      eq_traversal =
        eq do
          on Traversal.combine([Lens.key(:name), Lens.key(:age)])
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 30},
               eq_traversal
             )
    end

    test "Traversal with all foci present but not matching" do
      eq_traversal =
        eq do
          on Traversal.combine([Lens.key(:name), Lens.key(:age)])
        end

      refute Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "Alice", age: 25},
               eq_traversal
             )
    end

    test "Traversal with missing foci" do
      eq_traversal =
        eq do
          on Traversal.combine([Prism.key(:name), Prism.key(:missing_field)])
        end

      refute Utils.eq?(
               %Person{name: "Alice"},
               %Person{name: "Alice"},
               eq_traversal
             )
    end
  end

  describe "empty block" do
    test "identity - always equal" do
      eq_empty =
        eq do
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Bob"}, eq_empty)
      assert Utils.eq?(42, 99, eq_empty)
      assert Utils.eq?("hello", "world", eq_empty)
    end
  end

  describe "behaviour modules" do
    test "behaviour returns Eq map (compares by id)" do
      eq_by_id =
        eq do
          on UserById
        end

      assert Utils.eq?(%Person{id: 1, name: "Alice"}, %Person{id: 1, name: "Bob"}, eq_by_id)
      refute Utils.eq?(%Person{id: 1, name: "Alice"}, %Person{id: 2, name: "Alice"}, eq_by_id)
    end

    test "behaviour with options - case sensitive (default)" do
      eq_by_name =
        eq do
          on UserByName
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Alice"}, eq_by_name)
      refute Utils.eq?(%Person{name: "Alice"}, %Person{name: "alice"}, eq_by_name)
    end

    test "behaviour with options - case insensitive" do
      eq_by_name_ci =
        eq do
          on UserByName, case_sensitive: false
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "alice"}, eq_by_name_ci)
      assert Utils.eq?(%Person{name: "BOB"}, %Person{name: "bob"}, eq_by_name_ci)
      refute Utils.eq?(%Person{name: "Alice"}, %Person{name: "Bob"}, eq_by_name_ci)
    end

    test "behaviour in any block" do
      eq_any =
        eq do
          any do
            on UserById
            on :email
          end
        end

      # Same id OR same email
      assert Utils.eq?(%Person{id: 1, email: "a@test.com"}, %Person{id: 1, email: "b@test.com"}, eq_any)
      assert Utils.eq?(%Person{id: 1, email: "a@test.com"}, %Person{id: 2, email: "a@test.com"}, eq_any)
      refute Utils.eq?(%Person{id: 1, email: "a@test.com"}, %Person{id: 2, email: "b@test.com"}, eq_any)
    end
  end

  describe "helper functions" do
    test "0-arity helper returning Prism" do
      eq_helper =
        eq do
          on ProjectionHelpers.name_prism()
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "Alice"}, eq_helper)
    end

    test "0-arity helper returning Lens" do
      eq_helper =
        eq do
          on ProjectionHelpers.age_lens()
        end

      assert Utils.eq?(%Person{age: 30}, %Person{age: 30}, eq_helper)
    end

    test "helper with or_else" do
      eq_helper =
        eq do
          on ProjectionHelpers.name_prism(), or_else: "Unknown"
        end

      assert Utils.eq?(%Person{name: nil}, %Person{name: "Unknown"}, eq_helper)
    end
  end

  describe "Eq map helpers" do
    test "0-arity helper returning Eq map" do
      eq_helper =
        eq do
          on EqHelpers.name_case_insensitive()
        end

      assert Utils.eq?(%Person{name: "Alice"}, %Person{name: "alice"}, eq_helper)
      assert Utils.eq?(%Person{name: "BOB"}, %Person{name: "bob"}, eq_helper)
      refute Utils.eq?(%Person{name: "Alice"}, %Person{name: "Bob"}, eq_helper)
    end

    test "mixing Eq maps with regular projections" do
      eq_mixed =
        eq do
          on EqHelpers.name_case_insensitive()
          on :age
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "ALICE", age: 30},
               eq_mixed
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 30},
               %Person{name: "ALICE", age: 25},
               eq_mixed
             )
    end

    test "not_on with Eq map" do
      eq_not =
        eq do
          on :name
          not_on EqHelpers.age_mod_10()
        end

      # Same name, different ages with different mod 10
      assert Utils.eq?(
               %Person{name: "Alice", age: 25},
               %Person{name: "Alice", age: 36},
               eq_not
             )

      # Same name, same mod 10 -> should NOT be equal
      refute Utils.eq?(
               %Person{name: "Alice", age: 25},
               %Person{name: "Alice", age: 35},
               eq_not
             )
    end

    test "multiple Eq maps" do
      eq_both =
        eq do
          on EqHelpers.name_case_insensitive()
          on EqHelpers.age_mod_10()
        end

      assert Utils.eq?(
               %Person{name: "Alice", age: 25},
               %Person{name: "ALICE", age: 35},
               eq_both
             )

      refute Utils.eq?(
               %Person{name: "Alice", age: 25},
               %Person{name: "ALICE", age: 36},
               eq_both
             )
    end
  end

  describe "using Funx.Eq for protocol dispatch" do
    test "on Funx.Eq uses default protocol" do
      eq_default =
        eq do
          on Funx.Eq
        end

      # Uses Eq protocol for CaseInsensitiveString
      assert Utils.eq?(
               %CaseInsensitiveString{value: "Hello"},
               %CaseInsensitiveString{value: "hello"},
               eq_default
             )

      # Uses default == for other types
      assert Utils.eq?(42, 42, eq_default)
      refute Utils.eq?(42, 99, eq_default)
    end

    test "on Funx.Eq in any block" do
      eq_any =
        eq do
          any do
            on Funx.Eq     # Default equality
            on :special_id # OR special_id match
          end
        end

      # Test shows composability with default Eq
      # Maps differ in :id but match in :special_id, so any returns true
      assert Utils.eq?(%{id: 999, special_id: 100}, %{id: 1, special_id: 100}, eq_any)
      # Both conditions false (different overall, different special_id)
      refute Utils.eq?(%{id: 1, special_id: 100}, %{id: 1, special_id: 200}, eq_any)
    end
  end

  describe "struct modules" do
    test "bare struct module filters by type" do
      eq_check =
        eq do
          on Check
        end

      assert Utils.eq?(%Check{id: 1}, %Check{id: 2}, eq_check)
      refute Utils.eq?(%Check{id: 1}, %CreditCard{id: 1}, eq_check)
    end
  end

  describe "compile-time errors" do
    test "rejects invalid syntax" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              check(:name)
            end
          end
        )
      end
    end

    test "rejects or_else with captured function" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on &String.length/1, or_else: 0
            end
          end
        )
      end
    end

    test "rejects or_else with anonymous function" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on(fn x -> x.name end, or_else: "unknown")
            end
          end
        )
      end
    end

    test "rejects or_else with Lens.key" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on Lens.key(:name), or_else: "unknown"
            end
          end
        )
      end
    end

    test "rejects or_else with Lens.path" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on Lens.path([:name]), or_else: "unknown"
            end
          end
        )
      end
    end

    test "rejects or_else with Traversal" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on Traversal.combine([Lens.key(:name)]), or_else: "unknown"
            end
          end
        )
      end
    end

    test "rejects redundant or_else" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on {Prism.key(:score), 0}, or_else: 1
            end
          end
        )
      end
    end

    test "rejects or_else with behaviour module" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            defmodule TestBehaviour do
              @behaviour Funx.Eq.Dsl.Behaviour
              def project(v, _), do: v
            end

            eq do
              on TestBehaviour, or_else: 0
            end
          end
        )
      end
    end

    test "rejects module without eq?/2, eq/1, or __struct__/0" do
      defmodule NotABehaviour do
        def some_function, do: :ok
      end

      assert_raise CompileError, ~r/does not have eq\?\/2, eq\/1, or __struct__\/0/, fn ->
        Code.eval_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on NotABehaviour
            end
          end
        )
      end
    end

    test "rejects invalid projection type" do
      assert_raise CompileError, fn ->
        Code.compile_quoted(
          quote do
            use Funx.Eq.Dsl

            eq do
              on [1, 2, 3]
            end
          end
        )
      end
    end
  end
end
