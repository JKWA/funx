defmodule Funx.IdentityTest do
  @moduledoc false

  use Funx.TestCase, async: true

  import Funx.Identity
  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Summarizable, only: [summarize: 1]

  alias Funx.{Eq, Identity, Ord}

  doctest Funx.Identity

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

  describe "summarize/1" do
    test "summarizes a Identity with integer" do
      assert summarize(pure(42)) == {:integer, 42}
    end

    test "summarizes a Identity with string" do
      assert summarize(pure("hello")) == {:binary, 5}
    end

    test "summarizes a Identity with nested Just" do
      inner = pure(:ok)
      outer = pure(inner)
      assert summarize(outer) == {:atom, :ok}
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

  describe "Ord.lt?/2" do
    test "Identity returns true for less value" do
      assert Ord.lt?(pure(1), pure(2)) == true
    end

    test "Identity returns false for more value" do
      assert Ord.lt?(pure(2), pure(1)) == false
    end

    test "Identity returns false for equal values" do
      assert Ord.lt?(pure(1), pure(1)) == false
    end
  end

  describe "Ord.le?/2" do
    test "Identity returns true for less value" do
      assert Ord.le?(pure(1), pure(2)) == true
    end

    test "Identity returns true for equal values" do
      assert Ord.le?(pure(1), pure(1)) == true
    end

    test "Identity returns false for greater value" do
      assert Ord.le?(pure(2), pure(1)) == false
    end
  end

  describe "Ord.gt?/2" do
    test "Identity returns true for greater value" do
      assert Ord.gt?(pure(2), pure(1)) == true
    end

    test "Identity returns false for less value" do
      assert Ord.gt?(pure(1), pure(2)) == false
    end

    test "Identity returns false for equal values" do
      assert Ord.gt?(pure(1), pure(1)) == false
    end
  end

  describe "Ord.ge?/2" do
    test "Identity returns true for greater value" do
      assert Ord.ge?(pure(2), pure(1)) == true
    end

    test "Identity returns true for equal values" do
      assert Ord.ge?(pure(1), pure(1)) == true
    end

    test "Identity returns false for less value" do
      assert Ord.ge?(pure(1), pure(2)) == false
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
