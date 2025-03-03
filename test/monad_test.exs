defmodule Funx.MonadAnyTest do
  use ExUnit.Case, async: true
  alias Funx.Monad
  doctest Funx.Monad
  doctest Funx.Filterable
  doctest Funx.Foldable

  test "bind applies the function to the value" do
    assert Monad.bind(5, fn x -> x * 2 end) == 10
    assert Monad.bind("hello", fn x -> x <> " world" end) == "hello world"
  end

  test "map transforms the value" do
    assert Monad.map(10, &(&1 + 5)) == 15
    assert Monad.map(:ok, fn :ok -> :success end) == :success
  end

  test "ap applies a function to a value" do
    assert Monad.ap(fn x -> x * 3 end, 4) == 12
    assert Monad.ap(&String.upcase/1, "hello") == "HELLO"
  end

  test "left identity law" do
    value = 42
    func = fn x -> x * 2 end

    assert Monad.bind(value, func) == func.(value)
  end

  test "right identity law" do
    value = "monad"

    assert Monad.bind(value, &Function.identity/1) == value
  end

  test "associativity law" do
    value = 3
    f = fn x -> x + 2 end
    g = fn x -> x * 4 end

    left = Monad.bind(Monad.bind(value, f), g)
    right = Monad.bind(value, fn x -> Monad.bind(f.(x), g) end)

    assert left == right
  end
end
