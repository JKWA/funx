defmodule Funx.Monad.ReaderTest do
  @moduledoc false

  use ExUnit.Case
  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Monad.Reader

  alias Funx.Tappable

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

  describe "Tappable.tap/2" do
    test "returns the original Reader value unchanged" do
      reader =
        pure(5)
        |> Tappable.tap(fn x -> x * 2 end)

      assert run(reader, %{}) == 5
    end

    test "executes the side effect function" do
      test_pid = self()

      reader =
        pure(42)
        |> Tappable.tap(fn x ->
          send(test_pid, {:tapped, x})
        end)

      result = run(reader, %{})
      assert result == 42
      assert_received {:tapped, 42}
    end

    test "works in a pipeline" do
      test_pid = self()

      reader =
        pure(5)
        |> map(&(&1 * 2))
        |> Tappable.tap(fn x -> send(test_pid, {:step1, x}) end)
        |> map(&(&1 + 1))
        |> Tappable.tap(fn x -> send(test_pid, {:step2, x}) end)

      result = run(reader, %{})
      assert result == 11
      assert_received {:step1, 10}
      assert_received {:step2, 11}
    end

    test "discards the return value of the side effect function" do
      reader =
        pure(5)
        |> Tappable.tap(fn _x ->
          # Return value should be ignored
          :this_should_be_discarded
        end)

      assert run(reader, %{}) == 5
    end

    test "tap with environment access" do
      test_pid = self()

      reader =
        asks(& &1[:user_id])
        |> Tappable.tap(fn id -> send(test_pid, {:user_id, id}) end)
        |> map(&(&1 * 100))

      result = run(reader, %{user_id: 42})
      assert result == 4200
      assert_received {:user_id, 42}
    end

    test "tap with bind in pipeline" do
      test_pid = self()

      reader =
        pure(5)
        |> Tappable.tap(fn x -> send(test_pid, {:before_bind, x}) end)
        |> bind(fn x -> pure(x * 2) end)
        |> Tappable.tap(fn x -> send(test_pid, {:after_bind, x}) end)

      result = run(reader, %{})
      assert result == 10
      assert_received {:before_bind, 5}
      assert_received {:after_bind, 10}
    end
  end

  def add_one(x), do: x + 1

  describe "Funx.Monad protocol" do
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
