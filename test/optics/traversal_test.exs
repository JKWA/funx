defmodule Funx.Optics.TraversalTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Funx.Monad.Maybe
  alias Funx.Optics.{Lens, Prism, Traversal}

  # ============================================================================
  # Test Domain Structs
  # ============================================================================

  defmodule Item, do: defstruct([:name, :amount])
  defmodule CreditCard, do: defstruct([:name, :number, :expiry, :amount])
  defmodule Check, do: defstruct([:name, :routing_number, :account_number, :amount])
  defmodule Charge, do: defstruct([:item, :payment])
  defmodule Refund, do: defstruct([:item, :payment])
  defmodule Transaction, do: defstruct([:type])

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp fixture(:cc_charge, amount) do
    amount = amount || 500

    %Transaction{
      type: %Charge{
        item: %Item{name: "Camera", amount: amount},
        payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: amount}
      }
    }
  end

  defp fixture(:check_charge, amount) do
    amount = amount || 300

    %Transaction{
      type: %Charge{
        item: %Item{name: "Lens", amount: amount},
        payment: %Check{
          name: "Bob",
          routing_number: "111000025",
          account_number: "987654",
          amount: amount
        }
      }
    }
  end

  defp fixture(:cc_refund, amount) do
    amount = amount || 150

    %Transaction{
      type: %Refund{
        item: %Item{name: "Tripod", amount: amount},
        payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: amount}
      }
    }
  end

  defp fixture(:check_refund, amount) do
    amount = amount || 200

    %Transaction{
      type: %Refund{
        item: %Item{name: "Flash", amount: amount},
        payment: %Check{
          name: "Dave",
          routing_number: "222000025",
          account_number: "123456",
          amount: amount
        }
      }
    }
  end

  # ============================================================================
  # Domain Boundary Prisms
  # ============================================================================

  defp cc_payment_prism do
    Prism.compose([
      Prism.path([{Transaction, :type}]),
      Prism.path([{Charge, :payment}]),
      Prism.path([{CreditCard, :amount}])
    ])
  end

  defp check_payment_prism do
    Prism.compose([
      Prism.path([{Transaction, :type}]),
      Prism.path([{Charge, :payment}]),
      Prism.path([{Check, :amount}])
    ])
  end

  defp item_amount_lens do
    Lens.compose([Lens.path([:type, :item, :amount])])
  end

  # ============================================================================
  # Constructor Tests
  # ============================================================================

  describe "combine/1" do
    test "creates multi-focus traversal" do
      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      assert %Traversal{foci: [%Lens{}, %Lens{}]} = t
    end

    test "empty list creates empty traversal" do
      t = Traversal.combine([])
      assert %Traversal{foci: []} = t
    end
  end

  # ============================================================================
  # to_list/2 - Collection Mode Tests
  # ============================================================================

  describe "to_list/2" do
    test "extracts all lens foci in combine order" do
      t = Traversal.combine([Lens.key(:age), Lens.key(:name)])
      assert Traversal.to_list(%{name: "Alice", age: 30}, t) == [30, "Alice"]
    end

    test "works with composed lens paths" do
      path = Lens.compose([Lens.key(:user), Lens.key(:name)])
      t = Traversal.combine([path, Lens.key(:score)])
      assert Traversal.to_list(%{user: %{name: "Bob"}, score: 100}, t) == ["Bob", 100]
    end

    test "raises when lens focus missing" do
      t = Traversal.combine([Lens.key(:name)])
      assert_raise KeyError, fn -> Traversal.to_list(%{age: 30}, t) end
    end

    test "extracts matching prism foci, skips non-matching" do
      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      assert Traversal.to_list(%{name: "Alice"}, t) == ["Alice"]
      assert Traversal.to_list(%{name: "Alice", email: "a@ex.com"}, t) == ["Alice", "a@ex.com"]
    end

    test "domain boundaries: extracts from matching contexts" do
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])
      assert Traversal.to_list(fixture(:cc_charge, 75), t) == [75]
      assert Traversal.to_list(fixture(:check_charge, 50), t) == [50]
    end

    test "domain boundaries: skips non-matching contexts" do
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])
      assert Traversal.to_list(fixture(:cc_refund, 25), t) == []
    end

    test "mixed lens and prism: includes lens, conditionally includes prism" do
      t = Traversal.combine([Lens.key(:item), Prism.key(:refund)])
      assert Traversal.to_list(%{item: "A", refund: "B"}, t) == ["A", "B"]
      assert Traversal.to_list(%{item: "A"}, t) == ["A"]
    end

    test "mixed lens and prism: lens raises even when prism matches" do
      t = Traversal.combine([Lens.key(:required), Prism.key(:optional)])
      assert_raise KeyError, fn -> Traversal.to_list(%{optional: "value"}, t) end
    end

    test "transaction domain example: item + payment amounts" do
      t = Traversal.combine([item_amount_lens(), cc_payment_prism(), check_payment_prism()])
      assert Traversal.to_list(fixture(:cc_charge, 500), t) == [500, 500]
      assert Traversal.to_list(fixture(:check_charge, 300), t) == [300, 300]
      assert Traversal.to_list(fixture(:cc_refund, 150), t) == [150]
    end

    test "empty traversal returns empty list" do
      t = Traversal.combine([])
      assert Traversal.to_list(%{name: "Alice"}, t) == []
    end
  end

  # ============================================================================
  # to_list_maybe/2 - Enforcement Mode Tests
  # ============================================================================

  describe "to_list_maybe/2" do
    test "returns Just when all lens foci present" do
      t = Traversal.combine([Lens.key(:age), Lens.key(:name)])
      assert Traversal.to_list_maybe(%{name: "Alice", age: 30}, t) == Maybe.just([30, "Alice"])
    end

    test "works with composed lens paths" do
      path = Lens.compose([Lens.key(:user), Lens.key(:name)])
      t = Traversal.combine([path, Lens.key(:score)])
      result = Traversal.to_list_maybe(%{user: %{name: "Bob"}, score: 100}, t)
      assert result == Maybe.just(["Bob", 100])
    end

    test "raises when lens focus missing" do
      t = Traversal.combine([Lens.key(:name)])
      assert_raise KeyError, fn -> Traversal.to_list_maybe(%{age: 30}, t) end
    end

    test "returns Just when all prisms match" do
      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      result = Traversal.to_list_maybe(%{name: "Alice", email: "a@ex.com"}, t)
      assert result == Maybe.just(["Alice", "a@ex.com"])
    end

    test "returns Nothing when any prism doesn't match" do
      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      assert Traversal.to_list_maybe(%{name: "Alice"}, t) == Maybe.nothing()
    end

    test "domain boundaries: Just when boundary matches" do
      t = Traversal.combine([cc_payment_prism()])
      assert Traversal.to_list_maybe(fixture(:cc_charge, 75), t) == Maybe.just([75])
    end

    test "domain boundaries: Nothing when boundary doesn't match" do
      t = Traversal.combine([cc_payment_prism()])
      assert Traversal.to_list_maybe(fixture(:cc_refund, 25), t) == Maybe.nothing()
    end

    test "mixed lens and prism: Just when all present" do
      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      result = Traversal.to_list_maybe(%{name: "Alice", email: "a@ex.com"}, t)
      assert result == Maybe.just(["Alice", "a@ex.com"])
    end

    test "mixed lens and prism: Nothing when prism missing" do
      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      assert Traversal.to_list_maybe(%{name: "Alice"}, t) == Maybe.nothing()
    end

    test "mixed lens and prism: raises when lens missing" do
      t = Traversal.combine([Lens.key(:required), Prism.key(:optional)])
      assert_raise KeyError, fn -> Traversal.to_list_maybe(%{optional: "value"}, t) end
    end

    test "transaction domain example: enforces co-presence" do
      t = Traversal.combine([item_amount_lens(), cc_payment_prism()])
      assert Traversal.to_list_maybe(fixture(:cc_charge, 500), t) == Maybe.just([500, 500])
      assert Traversal.to_list_maybe(fixture(:cc_refund, 150), t) == Maybe.nothing()
    end

    test "empty traversal returns Just empty list" do
      t = Traversal.combine([])
      assert Traversal.to_list_maybe(%{name: "Alice"}, t) == Maybe.just([])
    end
  end

  # ============================================================================
  # preview/2 Tests
  # ============================================================================

  describe "preview/2" do
    test "returns first lens value" do
      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      assert Traversal.preview(%{name: "Alice", age: 30}, t) == Maybe.just("Alice")
    end

    test "raises when lens focus missing" do
      t = Traversal.combine([Lens.key(:email)])
      assert_raise KeyError, fn -> Traversal.preview(%{name: "Alice"}, t) end
    end

    test "returns first matching prism in combine order" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      assert Traversal.preview(%{name: "Alice", email: "a@ex.com"}, t) == Maybe.just("a@ex.com")
    end

    test "skips Nothing and returns first Just" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      assert Traversal.preview(%{name: "Alice"}, t) == Maybe.just("Alice")
    end

    test "returns Nothing when no prisms match" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
      assert Traversal.preview(%{name: "Alice"}, t) == Maybe.nothing()
    end

    test "mixed: returns first successful focus" do
      t = Traversal.combine([Prism.key(:email), Lens.key(:name)])
      assert Traversal.preview(%{name: "Alice"}, t) == Maybe.just("Alice")
      assert Traversal.preview(%{name: "Alice", email: "a@ex.com"}, t) == Maybe.just("a@ex.com")
    end

    test "respects combine order when multiple match" do
      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      assert Traversal.preview(%{name: "Alice", email: "a@ex.com"}, t) == Maybe.just("Alice")
    end

    test "empty traversal returns Nothing" do
      t = Traversal.combine([])
      assert Traversal.preview(%{name: "Alice"}, t) == Maybe.nothing()
    end
  end

  # ============================================================================
  # has/2 Tests
  # ============================================================================

  describe "has/2" do
    test "returns true when lens focus exists" do
      t = Traversal.combine([Lens.key(:name)])
      assert Traversal.has(%{name: "Alice"}, t) == true
    end

    test "raises when lens focus missing" do
      t = Traversal.combine([Lens.key(:email)])
      assert_raise KeyError, fn -> Traversal.has(%{name: "Alice"}, t) end
    end

    test "returns true when prism matches" do
      t = Traversal.combine([Prism.key(:name)])
      assert Traversal.has(%{name: "Alice"}, t) == true
    end

    test "returns false when prism doesn't match" do
      t = Traversal.combine([Prism.key(:email)])
      assert Traversal.has(%{name: "Alice"}, t) == false
    end

    test "returns true when any focus matches" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      assert Traversal.has(%{name: "Alice"}, t) == true
    end

    test "returns false when no foci match" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
      assert Traversal.has(%{name: "Alice"}, t) == false
    end

    test "returns false for empty traversal" do
      t = Traversal.combine([])
      assert Traversal.has(%{name: "Alice"}, t) == false
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: order preservation" do
    property "to_list preserves combine order for lenses" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 2, max_length: 5)) do
        lenses = Enum.map(keys, &Lens.key/1)
        t = Traversal.combine(lenses)
        data = Map.new(keys, fn key -> {key, "value_#{key}"} end)

        result = Traversal.to_list(data, t)
        expected = Enum.map(keys, fn key -> "value_#{key}" end)
        assert result == expected
      end
    end

    property "to_list preserves combine order for prisms" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 2, max_length: 5)) do
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(keys, fn key -> {key, "value_#{key}"} end)

        result = Traversal.to_list(data, t)
        expected = Enum.map(keys, fn key -> "value_#{key}" end)
        assert result == expected
      end
    end

    property "to_list_maybe preserves combine order" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 2, max_length: 5)) do
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(keys, fn key -> {key, "value_#{key}"} end)

        result = Traversal.to_list_maybe(data, t)
        expected = Enum.map(keys, fn key -> "value_#{key}" end)
        assert result == Maybe.just(expected)
      end
    end
  end

  describe "property: operation consistency" do
    property "preview returns first element of to_list" do
      check all(
              keys <- uniq_list_of(atom(:alphanumeric), min_length: 1, max_length: 5),
              num_present <- integer(0..length(keys))
            ) do
        present_keys = Enum.take(keys, num_present)
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        preview_result = Traversal.preview(data, t)
        list_result = Traversal.to_list(data, t)

        expected =
          case list_result do
            [] -> Maybe.nothing()
            [first | _] -> Maybe.just(first)
          end

        assert preview_result == expected
      end
    end

    property "has/2 consistent with preview/2" do
      check all(
              keys <- uniq_list_of(atom(:alphanumeric), min_length: 1, max_length: 5),
              num_present <- integer(0..length(keys))
            ) do
        present_keys = Enum.take(keys, num_present)
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        has_result = Traversal.has(data, t)
        preview_result = Traversal.preview(data, t)

        expected =
          case preview_result do
            %Maybe.Just{} -> true
            %Maybe.Nothing{} -> false
          end

        assert has_result == expected
      end
    end
  end

  describe "property: two-mode relationship" do
    property "lens-only traversal: to_list_maybe always returns Just" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 1, max_length: 5)) do
        lenses = Enum.map(keys, &Lens.key/1)
        t = Traversal.combine(lenses)
        data = Map.new(keys, fn key -> {key, "value_#{key}"} end)

        maybe_result = Traversal.to_list_maybe(data, t)
        list_result = Traversal.to_list(data, t)

        assert %Maybe.Just{value: values} = maybe_result
        assert values == list_result
      end
    end

    property "to_list_maybe Just implies to_list has same values" do
      check all(
              keys <- uniq_list_of(atom(:alphanumeric), min_length: 1, max_length: 5),
              num_present <- integer(0..length(keys))
            ) do
        present_keys = Enum.take(keys, num_present)
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        maybe_result = Traversal.to_list_maybe(data, t)
        list_result = Traversal.to_list(data, t)

        case maybe_result do
          %Maybe.Just{value: values} ->
            assert list_result == values

          %Maybe.Nothing{} ->
            assert is_list(list_result)
            assert length(list_result) < length(keys)
        end
      end
    end

    property "to_list_maybe Nothing when any prism doesn't match" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 2, max_length: 5)) do
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)

        [_missing_key | present_keys] = keys
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        maybe_result = Traversal.to_list_maybe(data, t)
        assert maybe_result == Maybe.nothing()

        list_result = Traversal.to_list(data, t)
        assert length(list_result) == length(present_keys)
      end
    end
  end

  describe "property: empty traversal laws" do
    property "empty traversal always returns empty/Nothing/false" do
      check all(data <- term()) do
        t = Traversal.combine([])

        assert Traversal.to_list(data, t) == []
        assert Traversal.to_list_maybe(data, t) == Maybe.just([])
        assert Traversal.preview(data, t) == Maybe.nothing()
        assert Traversal.has(data, t) == false
      end
    end
  end

  describe "property: single focus behavior" do
    property "single lens traversal behaves like direct lens operation" do
      check all(key <- atom(:alphanumeric)) do
        lens = Lens.key(key)
        t = Traversal.combine([lens])
        data = %{key => "value"}

        assert Traversal.to_list(data, t) == ["value"]
        assert Traversal.to_list_maybe(data, t) == Maybe.just(["value"])
        assert Traversal.preview(data, t) == Maybe.just("value")
        assert Traversal.has(data, t) == true
      end
    end

    property "single prism traversal behaves like direct prism operation" do
      check all(
              key <- atom(:alphanumeric),
              present <- boolean()
            ) do
        prism = Prism.key(key)
        t = Traversal.combine([prism])
        data = if present, do: %{key => "value"}, else: %{}

        prism_result = Prism.preview(data, prism)

        expected_list =
          case prism_result do
            %Maybe.Just{value: v} -> [v]
            %Maybe.Nothing{} -> []
          end

        expected_maybe =
          case prism_result do
            %Maybe.Just{value: v} -> Maybe.just([v])
            %Maybe.Nothing{} -> Maybe.nothing()
          end

        expected_has =
          case prism_result do
            %Maybe.Just{} -> true
            %Maybe.Nothing{} -> false
          end

        assert Traversal.to_list(data, t) == expected_list
        assert Traversal.to_list_maybe(data, t) == expected_maybe
        assert Traversal.preview(data, t) == prism_result
        assert Traversal.has(data, t) == expected_has
      end
    end
  end

  describe "property: lens raises on violation" do
    property "lens always raises when focus missing" do
      check all(key <- atom(:alphanumeric)) do
        lens = Lens.key(key)
        t = Traversal.combine([lens])
        data = %{}

        assert_raise KeyError, fn -> Traversal.to_list(data, t) end
        assert_raise KeyError, fn -> Traversal.to_list_maybe(data, t) end
        assert_raise KeyError, fn -> Traversal.preview(data, t) end
        assert_raise KeyError, fn -> Traversal.has(data, t) end
      end
    end

    property "lens raises even when combined with matching prisms" do
      check all(
              lens_key <- atom(:alphanumeric),
              prism_key <- atom(:alphanumeric),
              lens_key != prism_key
            ) do
        lens = Lens.key(lens_key)
        prism = Prism.key(prism_key)
        t = Traversal.combine([prism, lens])
        data = %{prism_key => "value"}

        assert_raise KeyError, fn -> Traversal.to_list(data, t) end
        assert_raise KeyError, fn -> Traversal.to_list_maybe(data, t) end
        assert_raise KeyError, fn -> Traversal.preview(data, t) end
        assert_raise KeyError, fn -> Traversal.has(data, t) end
      end
    end
  end

  describe "property: result length relationships" do
    property "to_list length <= number of foci" do
      check all(
              keys <- uniq_list_of(atom(:alphanumeric), min_length: 1, max_length: 10),
              num_present <- integer(0..length(keys))
            ) do
        present_keys = Enum.take(keys, num_present)
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        result = Traversal.to_list(data, t)

        assert length(result) <= length(keys)
        assert length(result) == length(present_keys)
      end
    end

    property "to_list_maybe returns Nothing when result length < number of foci" do
      check all(keys <- uniq_list_of(atom(:alphanumeric), min_length: 2, max_length: 10)) do
        prisms = Enum.map(keys, &Prism.key/1)
        t = Traversal.combine(prisms)

        present_keys = Enum.drop(keys, 1)
        data = Map.new(present_keys, fn key -> {key, "value_#{key}"} end)

        maybe_result = Traversal.to_list_maybe(data, t)
        assert maybe_result == Maybe.nothing()
      end
    end
  end
end
