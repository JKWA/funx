defmodule Funx.OrdAnyTest do
  @moduledoc false

  use ExUnit.Case
  alias Funx.Ord

  describe "Funx.Ord default (Any) implementation" do
    test "lt?/2 returns true for less value" do
      assert Ord.lt?(1, 2) == true
    end

    test "le?/2 returns true for equal values" do
      assert Ord.le?(1, 1) == true
    end

    test "gt?/2 returns true for greater value" do
      assert Ord.gt?(3, 2) == true
    end

    test "ge?/2 returns true for greater or equal values" do
      assert Ord.ge?(2, 2) == true
      assert Ord.ge?(3, 2) == true
    end
  end
end
