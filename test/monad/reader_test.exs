defmodule Monex.ReaderTest do
  use ExUnit.Case
  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]
  import Monex.Reader

  describe "pure/1" do
    test "wraps a value in the Reader monad" do
      reader = pure(42)
      assert run(reader, %{}) == 42
    end
  end

  describe "run/2" do
    test "executes a Reader with the given environment" do
      reader = asks(& &1[:key])
      assert run(reader, %{key: "value"}) == "value"
    end
  end

  describe "ask/0" do
    test "retrieves the entire environment" do
      env = %{config: "test_config"}
      reader = ask()
      assert run(reader, env) == env
    end
  end

  describe "asks/1" do
    test "applies a function to the environment" do
      reader = asks(& &1[:config])
      assert run(reader, %{config: "value"}) == "value"
    end
  end

  def add_one(x), do: x + 1

  describe "Monex.Monad protocol" do
    test "bind/2 chains Reader computations" do
      env = %{}
      func_reader = fn x -> pure(add_one(x)) end

      bound_reader =
        pure(5)
        |> bind(func_reader)
        |> run(env)

      assert bound_reader == 6
    end

    test "map/2 applies a function to the result within Reader" do
      env = %{}

      reader =
        pure(10)
        |> map(&add_one/1)
        |> run(env)

      assert reader == 11
    end

    test "ap/2 applies a function Reader to a value Reader" do
      env = %{}
      func_reader = pure(&add_one/1)
      value_reader = pure(41)

      applied_reader =
        func_reader
        |> ap(value_reader)
        |> run(env)

      assert applied_reader == 42
    end
  end
end
