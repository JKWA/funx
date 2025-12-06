defmodule Funx.Optics.LensTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest Funx.Optics.Lens

  alias Funx.Optics.Lens

  test "get/2 retrieves the focused value" do
    lens = Lens.key(:name)
    assert %{name: "Alice"} |> Lens.get(lens) == "Alice"
  end

  test "set/3 replaces the focused value" do
    lens = Lens.key(:count)
    result = %{count: 3} |> Lens.set(10, lens)
    assert result == %{count: 10}
  end

  test "compose/2 focuses through nested structures" do
    outer = Lens.key(:profile)
    inner = Lens.key(:score)
    lens = Lens.compose(outer, inner)

    data = %{profile: %{score: 5}}

    assert data |> Lens.get(lens) == 5

    updated = data |> Lens.set(9, lens)
    assert updated == %{profile: %{score: 9}}
  end

  test "path/1 gets nested values" do
    lens = Lens.path([:stats, :wins])
    assert %{stats: %{wins: 2}} |> Lens.get(lens) == 2
  end

  test "path/1 sets nested values" do
    lens = Lens.path([:stats, :losses])

    updated =
      %{stats: %{losses: 1}}
      |> Lens.set(4, lens)

    assert updated == %{stats: %{losses: 4}}
  end

  test "compose/2 behaves identically to nested path when structure matches" do
    a = Lens.key(:outer)
    b = Lens.key(:inner)
    composed = Lens.compose(a, b)

    path_lens = Lens.path([:outer, :inner])

    data = %{outer: %{inner: 7}}

    assert data |> Lens.get(composed) == data |> Lens.get(path_lens)

    updated1 = data |> Lens.set(9, composed)
    updated2 = data |> Lens.set(9, path_lens)

    assert updated1 == updated2
  end
end
