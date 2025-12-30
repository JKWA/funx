defmodule Funx.Monad.IdentityTest do
  @moduledoc false

  use Funx.TestCase, async: true

  import Funx.Monad.Identity
  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Summarizable, only: [summarize: 1]

  alias Funx.Eq
  alias Funx.Monad.Identity
  alias Funx.Ord.Protocol
  alias Funx.Tappable

  doctest Funx.Monad.Identity

  defp multiply_by_2(x), do: x * 2

  setup [:with_telemetry_config]

  describe "pure/1" do
    test "wraps a value in the Identity monad" do
      assert %Identity{value: 42} = pure(42)
    end
  end

  describe "Identity.extract/1" do
    test "extracts the value from the Identity monad" do
      assert 42 == pure(42) |> extract()
    end
  end

  describe "Tappable.tap/2" do
    test "returns the original Identity value unchanged" do
      result = Tappable.tap(pure(5), fn x -> x * 2 end)
      assert result == pure(5)
    end

    test "executes the side effect function" do
      test_pid = self()

      result =
        Tappable.tap(pure(42), fn x ->
          send(test_pid, {:tapped, x})
        end)

      assert result == pure(42)
      assert_received {:tapped, 42}
    end

    test "works in a pipeline" do
      test_pid = self()

      result =
        pure(5)
        |> map(&(&1 * 2))
        |> Tappable.tap(fn x -> send(test_pid, {:step1, x}) end)
        |> map(&(&1 + 1))
        |> Tappable.tap(fn x -> send(test_pid, {:step2, x}) end)

      assert result == pure(11)
      assert_received {:step1, 10}
      assert_received {:step2, 11}
    end

    test "discards the return value of the side effect function" do
      result =
        Tappable.tap(pure(5), fn _x ->
          # Return value should be ignored
          :this_should_be_discarded
        end)

      assert result == pure(5)
    end

    test "allows side effects like logging without changing the value" do
      result =
        pure(%{user: "alice", age: 30})
        |> Tappable.tap(fn user ->
          # Simulate logging
          send(self(), {:log, "Processing user: #{user.user}"})
        end)

      assert result == pure(%{user: "alice", age: 30})
      assert_received {:log, "Processing user: alice"}
    end

    test "tap with bind in pipeline" do
      test_pid = self()

      result =
        pure(5)
        |> Tappable.tap(fn x -> send(test_pid, {:before_bind, x}) end)
        |> bind(fn x -> pure(x * 2) end)
        |> Tappable.tap(fn x -> send(test_pid, {:after_bind, x}) end)

      assert result == pure(10)
      assert_received {:before_bind, 5}
      assert_received {:after_bind, 10}
    end
  end

  describe "summarize/1" do
    test "summarizes a Identity with integer" do
      assert summarize(pure(42)) == {:identity, {:integer, 42}}
    end

    test "summarizes a Identity with string" do
      assert summarize(pure("hello")) == {:identity, {:string, "hello"}}
    end

    test "summarizes a Identity with nested Just" do
      inner = pure(:ok)
      outer = pure(inner)
      assert summarize(outer) == {:identity, {:identity, {:atom, :ok}}}
    end
  end

  describe "ap/2" do
    test "applies a function in an Identity monad to a value in another Identity monad" do
      assert ap(pure(&(&1 + 1)), pure(42)) == pure(43)
    end
  end

  describe "bind/2" do
    test "applies a function returning a monad to the value inside the Identity monad" do
      assert %Identity{value: 21} =
               pure(42)
               |> bind(fn x -> pure(div(x, 2)) end)
    end
  end

  describe "map/2" do
    test "applies a function to the value inside the Identity monad" do
      assert %Identity{value: 20} = pure(10) |> map(&multiply_by_2/1)
    end
  end

  describe "String.Chars" do
    test "Identity value string representation" do
      identity_value = pure(42)
      assert to_string(identity_value) == "Identity(42)"
    end
  end

  describe "Eq.eq?/2" do
    test "returns true for equal Just values" do
      assert Eq.eq?(pure(1), pure(1)) == true
    end

    test "returns false for different Just values" do
      assert Eq.eq?(pure(1), pure(2)) == false
    end
  end

  describe "Eq.not_eq?/2" do
    test "returns false for equal Just values" do
      assert Eq.not_eq?(pure(1), pure(1)) == false
    end

    test "returns true for different Just values" do
      assert Eq.not_eq?(pure(1), pure(2)) == true
    end
  end

  describe "lift_eq/1" do
    setup do
      number_eq = %{eq?: &Kernel.==/2, not_eq?: &Kernel.!==/2}
      {:ok, eq: lift_eq(number_eq)}
    end

    test "eq?/2 returns true for equal values", %{eq: eq} do
      assert eq.eq?.(pure(1), pure(1)) == true
    end

    test "eq?/2 returns false for different values", %{eq: eq} do
      assert eq.eq?.(pure(1), pure(2)) == false
    end

    test "not_eq?/2 returns false for equal values", %{eq: eq} do
      assert eq.not_eq?.(pure(1), pure(1)) == false
    end

    test "not_eq?/2 returns true for different values", %{eq: eq} do
      assert eq.not_eq?.(pure(1), pure(2)) == true
    end
  end

  describe "Protocol.lt?/2" do
    test "Identity returns true for less value" do
      assert Protocol.lt?(pure(1), pure(2)) == true
    end

    test "Identity returns false for more value" do
      assert Protocol.lt?(pure(2), pure(1)) == false
    end

    test "Identity returns false for equal values" do
      assert Protocol.lt?(pure(1), pure(1)) == false
    end
  end

  describe "Protocol.le?/2" do
    test "Identity returns true for less value" do
      assert Protocol.le?(pure(1), pure(2)) == true
    end

    test "Identity returns true for equal values" do
      assert Protocol.le?(pure(1), pure(1)) == true
    end

    test "Identity returns false for greater value" do
      assert Protocol.le?(pure(2), pure(1)) == false
    end
  end

  describe "Protocol.gt?/2" do
    test "Identity returns true for greater value" do
      assert Protocol.gt?(pure(2), pure(1)) == true
    end

    test "Identity returns false for less value" do
      assert Protocol.gt?(pure(1), pure(2)) == false
    end

    test "Identity returns false for equal values" do
      assert Protocol.gt?(pure(1), pure(1)) == false
    end
  end

  describe "Protocol.ge?/2" do
    test "Identity returns true for greater value" do
      assert Protocol.ge?(pure(2), pure(1)) == true
    end

    test "Identity returns true for equal values" do
      assert Protocol.ge?(pure(1), pure(1)) == true
    end

    test "Identity returns false for less value" do
      assert Protocol.ge?(pure(1), pure(2)) == false
    end
  end

  describe "lift_ord/1" do
    setup do
      number_ord = %{
        lt?: &Kernel.</2,
        le?: &Kernel.<=/2,
        gt?: &Kernel.>/2,
        ge?: &Kernel.>=/2
      }

      {:ok, ord: lift_ord(number_ord)}
    end

    test "Orders Identity values based on their contained values", %{ord: ord} do
      assert ord.lt?.(pure(1), pure(2)) == true
      assert ord.le?.(pure(2), pure(2)) == true
      assert ord.gt?.(pure(3), pure(2)) == true
      assert ord.ge?.(pure(2), pure(2)) == true
    end
  end
end
