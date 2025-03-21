defmodule Funx.EqDateTimeTest do
  @moduledoc false

  use ExUnit.Case
  alias Funx.Eq

  describe "Funx.Eq implementation for DateTime" do
    setup do
      dt1 = ~U[2024-01-01 10:00:00Z]
      dt2 = ~U[2024-01-01 10:00:00Z]
      dt3 = ~U[2024-01-01 12:00:00Z]
      %{dt1: dt1, dt2: dt2, dt3: dt3}
    end

    test "eq?/2 returns true for equal datetimes", %{dt1: dt1, dt2: dt2} do
      assert Eq.eq?(dt1, dt2) == true
    end

    test "eq?/2 returns false for unequal datetimes", %{dt1: dt1, dt3: dt3} do
      assert Eq.eq?(dt1, dt3) == false
    end

    test "not_eq?/2 returns true for unequal datetimes", %{dt1: dt1, dt3: dt3} do
      assert Eq.not_eq?(dt1, dt3) == true
    end

    test "not_eq?/2 returns false for equal datetimes", %{dt1: dt1, dt2: dt2} do
      assert Eq.not_eq?(dt1, dt2) == false
    end
  end

  describe "Funx.Eq implementation for Date" do
    setup do
      d1 = ~D[2024-01-01]
      d2 = ~D[2024-01-01]
      d3 = ~D[2024-01-02]
      %{d1: d1, d2: d2, d3: d3}
    end

    test "eq?/2 returns true for equal dates", %{d1: d1, d2: d2} do
      assert Eq.eq?(d1, d2) == true
    end

    test "eq?/2 returns false for unequal dates", %{d1: d1, d3: d3} do
      assert Eq.eq?(d1, d3) == false
    end

    test "not_eq?/2 returns true for unequal dates", %{d1: d1, d3: d3} do
      assert Eq.not_eq?(d1, d3) == true
    end

    test "not_eq?/2 returns false for equal dates", %{d1: d1, d2: d2} do
      assert Eq.not_eq?(d1, d2) == false
    end
  end

  describe "Funx.Eq implementation for Time" do
    setup do
      t1 = ~T[10:00:00]
      t2 = ~T[10:00:00]
      t3 = ~T[12:00:00]
      %{t1: t1, t2: t2, t3: t3}
    end

    test "eq?/2 returns true for equal times", %{t1: t1, t2: t2} do
      assert Eq.eq?(t1, t2) == true
    end

    test "eq?/2 returns false for unequal times", %{t1: t1, t3: t3} do
      assert Eq.eq?(t1, t3) == false
    end

    test "not_eq?/2 returns true for unequal times", %{t1: t1, t3: t3} do
      assert Eq.not_eq?(t1, t3) == true
    end

    test "not_eq?/2 returns false for equal times", %{t1: t1, t2: t2} do
      assert Eq.not_eq?(t1, t2) == false
    end
  end

  describe "Funx.Eq implementation for NaiveDateTime" do
    setup do
      n1 = ~N[2024-01-01 10:00:00]
      n2 = ~N[2024-01-01 10:00:00]
      n3 = ~N[2024-01-01 12:00:00]
      %{n1: n1, n2: n2, n3: n3}
    end

    test "eq?/2 returns true for equal datetimes", %{n1: n1, n2: n2} do
      assert Eq.eq?(n1, n2) == true
    end

    test "eq?/2 returns false for unequal datetimes", %{n1: n1, n3: n3} do
      assert Eq.eq?(n1, n3) == false
    end

    test "not_eq?/2 returns true for unequal datetimes", %{n1: n1, n3: n3} do
      assert Eq.not_eq?(n1, n3) == true
    end

    test "not_eq?/2 returns false for equal datetimes", %{n1: n1, n2: n2} do
      assert Eq.not_eq?(n1, n2) == false
    end
  end
end
