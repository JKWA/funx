defmodule Funx.Optics.LensTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest Funx.Optics.Lens

  alias Funx.Optics.Lens

  test "get/2 retrieves the focused value" do
    lens = Lens.key(:name)
    assert Lens.get(lens, %{name: "Alice"}) == "Alice"
  end

  test "set/3 replaces the focused value" do
    lens = Lens.key(:count)
    result = Lens.set(lens, 10, %{count: 3})
    assert result == %{count: 10}
  end

  test "compose/2 focuses through nested structures" do
    outer = Lens.key(:profile)
    inner = Lens.key(:score)
    lens = Lens.compose(outer, inner)

    data = %{profile: %{score: 5}}
    assert Lens.get(lens, data) == 5

    updated = Lens.set(lens, 9, data)
    assert updated == %{profile: %{score: 9}}
  end

  test "path/1 gets nested values" do
    lens = Lens.path([:stats, :wins])
    assert Lens.get(lens, %{stats: %{wins: 2}}) == 2
  end

  test "path/1 sets nested values" do
    lens = Lens.path([:stats, :losses])
    updated = Lens.set(lens, 4, %{stats: %{losses: 1}})
    assert updated == %{stats: %{losses: 4}}
  end

  test "compose/2 behaves identically to nested path when structure matches" do
    a = Lens.key(:outer)
    b = Lens.key(:inner)
    composed = Lens.compose(a, b)

    path_lens = Lens.path([:outer, :inner])

    data = %{outer: %{inner: 7}}

    assert Lens.get(composed, data) == Lens.get(path_lens, data)

    updated1 = Lens.set(composed, 9, data)
    updated2 = Lens.set(path_lens, 9, data)

    assert updated1 == updated2
  end
end
