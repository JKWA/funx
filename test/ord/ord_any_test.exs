defmodule Funx.OrdAnyTest do
  @moduledoc false

  use ExUnit.Case
  alias Funx.Ord.Any

  describe "Funx.Ord.Any default implementation" do
    test "lt?/2 returns true for less value" do
      assert Any.lt?(1, 2) == true
    end

    test "le?/2 returns true for equal values" do
      assert Any.le?(1, 1) == true
    end

    test "gt?/2 returns true for greater value" do
      assert Any.gt?(3, 2) == true
    end

    test "ge?/2 returns true for greater or equal values" do
      assert Any.ge?(2, 2) == true
      assert Any.ge?(3, 2) == true
    end
  end
end
