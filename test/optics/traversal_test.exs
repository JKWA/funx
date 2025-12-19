defmodule Funx.Optics.TraversalTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Funx.Optics.{Lens, Prism, Traversal}

  # Domain structs for testing domain boundary prisms
  defmodule Item do
    defstruct [:name, :amount]
  end

  defmodule CreditCard do
    defstruct [:name, :number, :expiry, :amount]
  end

  defmodule Check do
    defstruct [:name, :routing_number, :account_number, :amount]
  end

  defmodule Charge do
    defstruct [:item, :payment]
  end

  defmodule Refund do
    defstruct [:item, :payment]
  end

  defmodule Transaction do
    defstruct [:type]
  end

  # Domain boundary prisms - these model "does this value exist in this context?"
  # not just "is this key present?"
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

  defp cc_refund_prism do
    Prism.compose([
      Prism.path([{Transaction, :type}]),
      Prism.path([{Refund, :payment}]),
      Prism.path([{CreditCard, :amount}])
    ])
  end

  defp check_refund_prism do
    Prism.compose([
      Prism.path([{Transaction, :type}]),
      Prism.path([{Refund, :payment}]),
      Prism.path([{Check, :amount}])
    ])
  end

  describe "combine/1" do
    test "creates a multi-focus traversal from a list of optics" do
      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      assert %Traversal{foci: [%Lens{}, %Lens{}]} = t
    end

    test "combine([]) creates identity traversal with no foci" do
      t = Traversal.combine([])
      assert %Traversal{foci: []} = t
    end
  end

  describe "to_list/2 with Lens only" do
    test "extracts values from all Lens foci" do
      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      data = %{name: "Alice", age: 30}

      assert Traversal.to_list(data, t) == ["Alice", 30]
    end

    test "preserves combine order" do
      t = Traversal.combine([Lens.key(:age), Lens.key(:name)])
      data = %{name: "Alice", age: 30}

      assert Traversal.to_list(data, t) == [30, "Alice"]
    end

    test "throws when Lens focus is invalid (contract violation)" do
      t = Traversal.combine([Lens.key(:name)])
      data = %{age: 30}

      assert_raise KeyError, fn ->
        Traversal.to_list(data, t)
      end
    end

    test "works with composed Lens paths" do
      path = Lens.compose([Lens.key(:user), Lens.key(:name)])
      t = Traversal.combine([path, Lens.key(:score)])
      data = %{user: %{name: "Bob"}, score: 100}

      assert Traversal.to_list(data, t) == ["Bob", 100]
    end
  end

  describe "to_list/2 with Prism only" do
    test "extracts values from matching domain boundaries" do
      # Create transactions that match different domain boundaries
      cc_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Camera", amount: 500},
            payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: 75}
          }
        }

      check_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Lens", amount: 300},
            payment: %Check{
              name: "Bob",
              routing_number: "111000025",
              account_number: "987654",
              amount: 50
            }
          }
        }

      # Traversal across both payment types
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])

      # cc_charge matches cc_payment_prism but not check_payment_prism
      assert Traversal.to_list(cc_charge, t) == [75]

      # check_charge matches check_payment_prism but not cc_payment_prism
      assert Traversal.to_list(check_charge, t) == [50]
    end

    test "extracts values from refund domain boundaries" do
      # Refunds exist in different domain contexts than charges
      cc_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Tripod", amount: 150},
            payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: 25}
          }
        }

      check_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Flash", amount: 200},
            payment: %Check{
              name: "Dave",
              routing_number: "222000025",
              account_number: "123456",
              amount: 30
            }
          }
        }

      # Traversal across both refund types
      t = Traversal.combine([cc_refund_prism(), check_refund_prism()])

      # cc_refund matches cc_refund_prism but not check_refund_prism
      assert Traversal.to_list(cc_refund, t) == [25]

      # check_refund matches check_refund_prism but not cc_refund_prism
      assert Traversal.to_list(check_refund, t) == [30]
    end

    test "skips Prism Nothing when domain boundary doesn't match" do
      # A refund doesn't exist in the "charge" context
      cc_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Tripod", amount: 150},
            payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: 25}
          }
        }

      # Combine charge prisms - refund doesn't match either
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])

      # Neither charge prism matches a refund transaction
      result = Traversal.to_list(cc_refund, t)
      assert result == []
    end

    test "returns empty list when no domain boundaries match" do
      # A check refund doesn't match cc_payment or check_payment boundaries
      check_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Flash", amount: 200},
            payment: %Check{
              name: "Dave",
              routing_number: "222000025",
              account_number: "123456",
              amount: 30
            }
          }
        }

      # Neither payment prism matches a refund
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])

      result = Traversal.to_list(check_refund, t)
      assert result == []
    end

    test "simple key prisms still work for basic cases" do
      t = Traversal.combine([Prism.key(:name), Prism.key(:age)])
      data = %{name: "Alice", age: 30}

      result = Traversal.to_list(data, t)
      assert result == ["Alice", 30]
    end
  end

  describe "to_list/2 with mixed Lens and Prism" do
    test "combines Lens (always) and Prism (conditional) values" do
      t =
        Traversal.combine([
          Lens.key(:item),
          Prism.key(:refund)
        ])

      # Case 1: Prism matches
      data_with_refund = %{item: "A", refund: "B"}
      assert Traversal.to_list(data_with_refund, t) == ["A", "B"]

      # Case 2: Prism doesn't match
      data_without_refund = %{item: "A"}
      assert Traversal.to_list(data_without_refund, t) == ["A"]
    end

    test "Lens throws even when mixed with Prisms" do
      t =
        Traversal.combine([
          Lens.key(:required),
          Prism.key(:optional)
        ])

      data = %{optional: "value"}

      assert_raise KeyError, fn ->
        Traversal.to_list(data, t)
      end
    end

    test "transaction example: item.amount and payment amounts across domain boundaries" do
      # Build a lens for item amount (always exists)
      item_amount = Lens.compose([Lens.path([:type, :item, :amount])])

      # Combine with payment prisms (conditional existence based on domain boundary)
      t = Traversal.combine([item_amount, cc_payment_prism(), check_payment_prism()])

      # Case 1: Credit card charge - item + cc_payment match
      cc_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Camera", amount: 500},
            payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: 520}
          }
        }

      assert Traversal.to_list(cc_charge, t) == [500, 520]

      # Case 2: Check charge - item + check_payment match
      check_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Lens", amount: 300},
            payment: %Check{
              name: "Bob",
              routing_number: "111000025",
              account_number: "987654",
              amount: 310
            }
          }
        }

      assert Traversal.to_list(check_charge, t) == [300, 310]

      # Case 3: Refund - item exists but payment prisms don't match (wrong domain boundary)
      cc_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Tripod", amount: 150},
            payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: 155}
          }
        }

      # Only item.amount extracted, payment prisms skip (refund != charge)
      assert Traversal.to_list(cc_refund, t) == [150]
    end
  end

  describe "to_list/2 with empty traversal" do
    test "returns empty list" do
      t = Traversal.combine([])
      data = %{name: "Alice"}

      assert Traversal.to_list(data, t) == []
    end
  end

  describe "preview/2 with Lens only" do
    test "returns first Lens value" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      data = %{name: "Alice", age: 30}

      assert Traversal.preview(data, t) == Maybe.just("Alice")
    end

    test "throws when Lens focus is invalid (contract violation)" do
      t = Traversal.combine([Lens.key(:email)])
      data = %{name: "Alice"}

      assert_raise KeyError, fn ->
        Traversal.preview(data, t)
      end
    end
  end

  describe "preview/2 with Prism only" do
    test "returns first matching Prism value" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      data = %{name: "Alice", email: "alice@example.com"}

      # email comes first in combine order
      assert Traversal.preview(data, t) == Maybe.just("alice@example.com")
    end

    test "skips Nothing and returns first Just" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      data = %{name: "Alice"}

      # email is Nothing, name is Just
      assert Traversal.preview(data, t) == Maybe.just("Alice")
    end

    test "returns Nothing when no Prisms match" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
      data = %{name: "Alice"}

      assert Traversal.preview(data, t) == Maybe.nothing()
    end
  end

  describe "preview/2 with mixed Lens and Prism" do
    test "returns first successful focus (Lens before Prism)" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      data = %{name: "Alice", email: "alice@example.com"}

      assert Traversal.preview(data, t) == Maybe.just("Alice")
    end

    test "returns first successful focus (Prism before Lens)" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:email), Lens.key(:name)])
      data = %{name: "Alice", email: "alice@example.com"}

      assert Traversal.preview(data, t) == Maybe.just("alice@example.com")
    end

    test "skips Prism Nothing and returns Lens value" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:email), Lens.key(:name)])
      data = %{name: "Alice"}

      assert Traversal.preview(data, t) == Maybe.just("Alice")
    end
  end

  describe "preview/2 respects combine order" do
    test "first success wins even with multiple matches" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      data = %{name: "Alice", email: "alice@example.com"}

      # name comes first, so it wins
      assert Traversal.preview(data, t) == Maybe.just("Alice")
    end
  end

  describe "preview/2 with empty traversal" do
    test "returns Nothing" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([])
      data = %{name: "Alice"}

      assert Traversal.preview(data, t) == Maybe.nothing()
    end
  end

  describe "has/2" do
    test "returns true when Lens focus exists" do
      t = Traversal.combine([Lens.key(:name)])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == true
    end

    test "throws when Lens focus is invalid (contract violation)" do
      t = Traversal.combine([Lens.key(:email)])
      data = %{name: "Alice"}

      assert_raise KeyError, fn ->
        Traversal.has(data, t)
      end
    end

    test "returns true when Prism focus matches" do
      t = Traversal.combine([Prism.key(:name)])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == true
    end

    test "returns false when Prism focus doesn't match" do
      t = Traversal.combine([Prism.key(:email)])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == false
    end

    test "returns true when any focus matches" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:name)])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == true
    end

    test "returns false when no foci match" do
      t = Traversal.combine([Prism.key(:email), Prism.key(:phone)])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == false
    end

    test "returns false for empty traversal" do
      t = Traversal.combine([])
      data = %{name: "Alice"}

      assert Traversal.has(data, t) == false
    end
  end

  describe "traverse/3 with Lens only" do
    test "returns Just(rebuilt structure) when all Lens foci exist and function succeeds" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      data = %{name: "Alice", age: 30}

      result =
        Traversal.traverse(data, t, fn value ->
          Maybe.just(String.upcase(to_string(value)))
        end)

      assert result == Maybe.just(%{name: "ALICE", age: "30"})
    end

    test "returns Nothing when function returns Nothing for any focus" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Lens.key(:age)])
      data = %{name: "Alice", age: 30}

      result =
        Traversal.traverse(data, t, fn
          value when is_binary(value) -> Maybe.just(value)
          _value -> Maybe.nothing()
        end)

      assert result == Maybe.nothing()
    end

    test "throws when Lens focus is invalid (contract violation)" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:email)])
      data = %{name: "Alice"}

      assert_raise KeyError, fn ->
        Traversal.traverse(data, t, fn v -> Maybe.just(v) end)
      end
    end
  end

  describe "traverse/3 with Prism only" do
    test "returns Just(rebuilt structure) when all domain boundaries match" do
      alias Funx.Monad.Maybe

      # All credit card charges - homogeneous with respect to cc_payment_prism
      cc_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Camera", amount: 500},
            payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: 520}
          }
        }

      t = Traversal.combine([cc_payment_prism()])

      # Apply a 10% fee to all matching payments
      result =
        Traversal.traverse(cc_charge, t, fn amount ->
          Maybe.just(trunc(amount * 1.1))
        end)

      # Transaction structure rebuilt with updated amount
      assert %Maybe.Just{
               value: %Transaction{
                 type: %Charge{
                   payment: %CreditCard{amount: 572}
                 }
               }
             } = result
    end

    test "returns Nothing when domain boundary doesn't match - not an error, wrong context" do
      alias Funx.Monad.Maybe

      # A refund doesn't exist in the "charge" context
      cc_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Tripod", amount: 150},
            payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: 155}
          }
        }

      # This isn't "bad data" - it's valid, just not in the cc_payment context
      t = Traversal.combine([cc_payment_prism()])

      result = Traversal.traverse(cc_refund, t, fn v -> Maybe.just(v) end)

      # Nothing because refund != charge, not because data is malformed
      assert result == Maybe.nothing()
    end

    test "returns Nothing when function returns Nothing" do
      alias Funx.Monad.Maybe

      cc_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Camera", amount: 500},
            payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: 520}
          }
        }

      t = Traversal.combine([cc_payment_prism()])

      # Function rejects the value
      result = Traversal.traverse(cc_charge, t, fn _ -> Maybe.nothing() end)

      assert result == Maybe.nothing()
    end

    test "returns Nothing when mixing domain boundaries - enforces homogeneity" do
      alias Funx.Monad.Maybe

      # Transaction is BOTH a cc_payment and a check_payment? No, impossible.
      # This test shows traverse enforces that all foci must exist
      cc_charge =
        %Transaction{
          type: %Charge{
            item: %Item{name: "Camera", amount: 500},
            payment: %CreditCard{name: "Alice", number: "1234", expiry: "12/26", amount: 520}
          }
        }

      # Traversal expects BOTH cc_payment AND check_payment to exist
      t = Traversal.combine([cc_payment_prism(), check_payment_prism()])

      # cc_charge matches cc_payment but NOT check_payment
      # traverse is all-or-nothing, so this returns Nothing
      result = Traversal.traverse(cc_charge, t, fn amount -> Maybe.just(amount * 2) end)

      assert result == Maybe.nothing()
    end

    test "refund prisms work in refund context but not charge context" do
      alias Funx.Monad.Maybe

      # A credit card refund exists in the cc_refund context
      cc_refund =
        %Transaction{
          type: %Refund{
            item: %Item{name: "Tripod", amount: 150},
            payment: %CreditCard{name: "Carol", number: "4333", expiry: "10/27", amount: 155}
          }
        }

      # Traversal with cc_refund_prism
      t = Traversal.combine([cc_refund_prism()])

      result =
        Traversal.traverse(cc_refund, t, fn amount ->
          Maybe.just(trunc(amount * 0.9))
        end)

      # Should succeed - refund exists in cc_refund context
      assert %Maybe.Just{
               value: %Transaction{
                 type: %Refund{
                   payment: %CreditCard{amount: 139}
                 }
               }
             } = result
    end

    test "simple key prisms still work for basic cases" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Prism.key(:name), Prism.key(:email)])
      data = %{name: "Alice", email: "alice@example.com"}

      result =
        Traversal.traverse(data, t, fn value ->
          Maybe.just(String.upcase(value))
        end)

      assert result == Maybe.just(%{name: "ALICE", email: "ALICE@EXAMPLE.COM"})
    end
  end

  describe "traverse/3 with mixed Lens and Prism" do
    test "returns Just(rebuilt structure) when all foci exist and function succeeds" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      data = %{name: "Alice", email: "alice@example.com"}

      result =
        Traversal.traverse(data, t, fn value ->
          Maybe.just(String.upcase(value))
        end)

      assert result == Maybe.just(%{name: "ALICE", email: "ALICE@EXAMPLE.COM"})
    end

    test "returns Nothing when Prism doesn't match" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      data = %{name: "Alice"}

      result = Traversal.traverse(data, t, fn v -> Maybe.just(v) end)

      assert result == Maybe.nothing()
    end

    test "returns Nothing when function returns Nothing" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name), Prism.key(:email)])
      data = %{name: "Alice", email: "alice@example.com"}

      result =
        Traversal.traverse(data, t, fn
          "Alice" -> Maybe.just("ALICE")
          _ -> Maybe.nothing()
        end)

      assert result == Maybe.nothing()
    end

    test "throws when Lens is invalid even if Prism would fail" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:required), Prism.key(:optional)])
      data = %{other: "value"}

      assert_raise KeyError, fn ->
        Traversal.traverse(data, t, fn v -> Maybe.just(v) end)
      end
    end
  end

  describe "traverse/3 with empty traversal" do
    test "returns Just(original structure) unchanged" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([])
      data = %{name: "Alice"}

      result = Traversal.traverse(data, t, fn v -> Maybe.just(v) end)

      assert result == Maybe.just(data)
    end
  end

  describe "traverse/3 structure rebuilding" do
    test "rebuilds structure preserving non-traversed fields" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:name)])
      data = %{name: "Alice", age: 30, city: "NYC"}

      result =
        Traversal.traverse(data, t, fn value ->
          Maybe.just(String.upcase(value))
        end)

      assert result == Maybe.just(%{name: "ALICE", age: 30, city: "NYC"})
    end

    test "applies updates in traversal order" do
      alias Funx.Monad.Maybe

      t = Traversal.combine([Lens.key(:a), Lens.key(:b)])
      data = %{a: 1, b: 2}

      result =
        Traversal.traverse(data, t, fn value ->
          Maybe.just(value * 10)
        end)

      assert result == Maybe.just(%{a: 10, b: 20})
    end
  end
end
