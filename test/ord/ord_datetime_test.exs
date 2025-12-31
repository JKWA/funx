defmodule Funx.OrdDateTimeTest do
  @moduledoc false

  use ExUnit.Case
  alias Funx.Ord.Protocol

  describe "Funx.Ord implementation for DateTime" do
    setup do
      dt1 = ~U[2024-01-01 10:00:00Z]
      dt2 = ~U[2024-01-01 12:00:00Z]
      dt3 = ~U[2024-01-01 12:00:00Z]
      %{dt1: dt1, dt2: dt2, dt3: dt3}
    end

    test "lt?/2 returns true for earlier datetime", %{dt1: dt1, dt2: dt2} do
      assert Protocol.lt?(dt1, dt2) == true
    end

    test "le?/2 returns true for earlier or equal datetime", %{dt1: dt1, dt2: dt2, dt3: dt3} do
      assert Protocol.le?(dt1, dt2) == true
      assert Protocol.le?(dt2, dt3) == true
    end

    test "gt?/2 returns true for later datetime", %{dt1: dt1, dt2: dt2} do
      assert Protocol.gt?(dt2, dt1) == true
    end

    test "ge?/2 returns true for later or equal datetime", %{dt1: dt1, dt2: dt2, dt3: dt3} do
      assert Protocol.ge?(dt2, dt1) == true
      assert Protocol.ge?(dt2, dt3) == true
    end
  end

  describe "Funx.Ord implementation for Date" do
    setup do
      d1 = ~D[2024-01-01]
      d2 = ~D[2024-01-01]
      d3 = ~D[2024-01-02]
      %{d1: d1, d2: d2, d3: d3}
    end

    test "lt?/2 returns true for earlier date", %{d1: d1, d3: d3} do
      assert Protocol.lt?(d1, d3) == true
    end

    test "le?/2 returns true for earlier or equal dates", %{d1: d1, d2: d2, d3: d3} do
      assert Protocol.le?(d1, d3) == true
      assert Protocol.le?(d2, d1) == true
    end

    test "gt?/2 returns true for later date", %{d1: d1, d3: d3} do
      assert Protocol.gt?(d3, d1) == true
    end

    test "ge?/2 returns true for later or equal dates", %{d1: d1, d2: d2, d3: d3} do
      assert Protocol.ge?(d3, d1) == true
      assert Protocol.ge?(d1, d2) == true
    end
  end

  describe "Funx.Ord implementation for Time" do
    setup do
      t1 = ~T[10:00:00]
      t2 = ~T[10:00:00]
      t3 = ~T[12:00:00]
      %{t1: t1, t2: t2, t3: t3}
    end

    test "lt?/2 returns true for earlier time", %{t1: t1, t3: t3} do
      assert Protocol.lt?(t1, t3) == true
    end

    test "le?/2 returns true for earlier or equal times", %{t1: t1, t2: t2, t3: t3} do
      assert Protocol.le?(t1, t3) == true
      assert Protocol.le?(t2, t1) == true
    end

    test "gt?/2 returns true for later time", %{t1: t1, t3: t3} do
      assert Protocol.gt?(t3, t1) == true
    end

    test "ge?/2 returns true for later or equal times", %{t1: t1, t2: t2, t3: t3} do
      assert Protocol.ge?(t3, t1) == true
      assert Protocol.ge?(t1, t2) == true
    end
  end

  describe "Funx.Ord implementation for NaiveDateTime" do
    setup do
      n1 = ~N[2024-01-01 10:00:00]
      n2 = ~N[2024-01-01 10:00:00]
      n3 = ~N[2024-01-01 12:00:00]
      %{n1: n1, n2: n2, n3: n3}
    end

    test "lt?/2 returns true for earlier datetime", %{n1: n1, n3: n3} do
      assert Protocol.lt?(n1, n3) == true
    end

    test "le?/2 returns true for earlier or equal datetimes", %{n1: n1, n2: n2, n3: n3} do
      assert Protocol.le?(n1, n3) == true
      assert Protocol.le?(n2, n1) == true
    end

    test "gt?/2 returns true for later datetime", %{n1: n1, n3: n3} do
      assert Protocol.gt?(n3, n1) == true
    end

    test "ge?/2 returns true for later or equal datetimes", %{n1: n1, n2: n2, n3: n3} do
      assert Protocol.ge?(n3, n1) == true
      assert Protocol.ge?(n1, n2) == true
    end
  end
end
