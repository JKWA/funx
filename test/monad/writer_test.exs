defmodule WriterTest do
  use ExUnit.Case

  doctest Funx.Monad.Writer

  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Monad.Writer

  alias Funx.Monad.Writer
  alias Funx.Monoid.StringConcat

  test "pure wraps value with no log" do
    result =
      pure(42)
      |> run()

    assert result.value == 42
    assert result.log == []
  end

  test "writer injects both value and log" do
    result =
      writer({:ok, [:log1, :log2]})
      |> run()

    assert result.value == :ok
    assert result.log == [:log1, :log2]
  end

  test "tell adds log with :ok value" do
    result =
      tell([:log1])
      |> run()

    assert result.value == :ok
    assert result.log == [:log1]
  end

  test "tap returns the original Writer value unchanged" do
    result =
      pure(5)
      |> Writer.tap(fn x -> x * 2 end)
      |> run()

    assert result.value == 5
    assert result.log == []
  end

  test "tap does not add to the log" do
    result =
      writer({42, [:initial]})
      |> Writer.tap(fn _x -> :side_effect end)
      |> run()

    assert result.value == 42
    assert result.log == [:initial]
  end

  test "tap executes the side effect function" do
    test_pid = self()

    result =
      pure(42)
      |> Writer.tap(fn x ->
        send(test_pid, {:tapped, x})
      end)
      |> run()

    assert result.value == 42
    assert_received {:tapped, 42}
  end

  test "tap works in a pipeline" do
    test_pid = self()

    result =
      pure(5)
      |> map(&(&1 * 2))
      |> Writer.tap(fn x -> send(test_pid, {:step1, x}) end)
      |> map(&(&1 + 1))
      |> Writer.tap(fn x -> send(test_pid, {:step2, x}) end)
      |> run()

    assert result.value == 11
    assert result.log == []
    assert_received {:step1, 10}
    assert_received {:step2, 11}
  end

  test "tap discards the return value of the side effect function" do
    result =
      pure(5)
      |> Writer.tap(fn _x ->
        # Return value should be ignored
        :this_should_be_discarded
      end)
      |> run()

    assert result.value == 5
  end

  test "tap vs tell - tap does not log" do
    tap_result =
      pure(42)
      |> Writer.tap(fn _x -> :side_effect end)
      |> run()

    tell_result =
      pure(42)
      |> bind(fn x ->
        tell([:logged])
        |> map(fn _ -> x end)
      end)
      |> run()

    assert tap_result.log == []
    assert tell_result.log == [:logged]
  end

  test "tap with bind and tell in pipeline" do
    test_pid = self()

    result =
      pure(5)
      |> Writer.tap(fn x -> send(test_pid, {:before_tell, x}) end)
      |> bind(fn x ->
        tell([:processing])
        |> map(fn _ -> x * 2 end)
      end)
      |> Writer.tap(fn x -> send(test_pid, {:after_tell, x}) end)
      |> run()

    assert result.value == 10
    assert result.log == [:processing]
    assert_received {:before_tell, 5}
    assert_received {:after_tell, 10}
  end

  test "listen returns both the result and the accumulated log" do
    result =
      writer({42, [:step1]})
      |> listen()
      |> run()

    assert result.value == {42, [:step1]}
    assert result.log == [:step1]
  end

  test "censor transforms the final log without changing the result" do
    result =
      writer({42, [:a, :b]})
      |> censor(fn log -> Enum.reverse(log) end)
      |> run()

    assert result.value == 42
    assert result.log == [:b, :a]
  end

  test "censor after listen modifies only the logged portion" do
    result =
      writer({:done, [:step1, :step2]})
      |> censor(fn log -> Enum.take(log, 1) end)
      |> listen()
      |> run()

    assert result.value == {:done, [:step1]}
    assert result.log == [:step1]
  end

  test "pass applies returned log-transforming function" do
    writer =
      writer({:ok, [:init]})
      |> Funx.Monad.bind(fn _ ->
        pass(writer({{:done, fn log -> log ++ [:extra] end}, [:step]}))
      end)

    result = run(writer)

    assert result.value == :done
    assert result.log == [:init, :step, :extra]
  end

  test "exec returns only the final log" do
    log =
      writer({:ok, [:a, :b]})
      |> exec()

    assert log == [:a, :b]
  end

  test "eval returns only the final result" do
    value =
      writer({99, [:log]})
      |> eval()

    assert value == 99
  end

  test "writer works with StringConcat monoid" do
    result =
      writer({"ok", " init"})
      |> run(%StringConcat{})

    assert result.value == "ok"
    assert result.log == " init"
  end

  test "tell accumulates string logs using StringConcat" do
    result =
      tell("a ")
      |> bind(fn _ -> tell("b") end)
      |> run(%StringConcat{})

    assert result.value == :ok
    assert result.log == "a b"
  end

  test "censor reverses string log using StringConcat" do
    result =
      writer({"ok", "abcd"})
      |> censor(&String.reverse/1)
      |> run(%StringConcat{})

    assert result.value == "ok"
    assert result.log == "dcba"
  end

  test "map transforms result, leaves log" do
    add_five = fn x -> x + 5 end

    result =
      pure(2)
      |> map(add_five)
      |> run()

    assert result.value == 7
    assert result.log == []
  end

  test "bind sequences computation and accumulates logs" do
    kl_func = fn x ->
      tell([:step1])
      |> bind(fn _ -> pure(x + 1) end)
    end

    result =
      pure(1)
      |> bind(kl_func)
      |> run()

    assert result.value == 2
    assert result.log == [:step1]
  end

  test "ap applies function in context and combines logs" do
    f =
      tell([:func])
      |> map(fn _ -> fn x -> x + 1 end end)

    x =
      tell([:val])
      |> map(fn _ -> 4 end)

    result =
      ap(f, x)
      |> run()

    assert result.value == 5
    assert result.log == [:func, :val]
  end
end
