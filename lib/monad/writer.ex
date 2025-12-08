defmodule Funx.Monad.Writer do
  @moduledoc """
  The `Funx.Monad.Writer` module defines the Writer monad, which threads a log alongside a computed result.

  Logs are accumulated using a `Monoid` implementation, injected lazily at runtime. This makes the Writer monad flexible and monoid-polymorphic—supporting lists, strings, or any user-defined monoid.

  ### Core functions

    * `pure/1` – Wraps a result with an empty log.
    * `writer/1` – Wraps a result and an explicit log.
    * `tell/1` – Emits a log with no result.
    * `listen/1` – Returns both result and log as a pair.
    * `censor/2` – Applies a function to transform the final log.
    * `pass/1` – Uses a log-transforming function returned from within the computation.
    * `run/2` – Executes the Writer and returns a `%Writer.Result{}` with result and log.
    * `eval/2` – Executes and returns only the result.
    * `exec/2` – Executes and returns only the log.

  By default, the `ListConcat` monoid is used unless a different monoid is passed to `run`, `eval`, or `exec`.

  This module implements the following protocols:

    * `Funx.Monad`: Implements `bind/2`, `map/2`, and `ap/2` for monadic composition.
    * `Funx.Tappable`: Executes side effects on the computed value via `Funx.Tappable.tap/2`.
  """

  import Funx.Monoid, only: [wrap: 2, append: 2, unwrap: 1]
  alias Funx.Monad.Writer
  alias Funx.Monoid.ListConcat

  defstruct [:writer]

  @typedoc """
  Represents a computation that produces a result along with a log,
  accumulated using a monoid.

  The internal `writer` function takes an initial monoid and returns
  a `{value, monoid}` tuple, where the monoid contains the accumulated log.
  """

  # @type t() :: %__MODULE__{
  #         writer: (term() -> {term(), term()})
  #       }

  @type t(a) :: %__MODULE__{writer: (term() -> {a, term()})}

  @doc """
  Wraps a value with no log.

  ## Example

      iex> writer = Funx.Monad.Writer.pure(42)
      iex> result = Funx.Monad.Writer.run(writer)
      iex> result.value
      42
      iex> result.log
      []
  """
  @spec pure(a) :: t(a) when a: term()
  def pure(value) do
    %__MODULE__{
      writer: fn monoid -> {value, monoid} end
    }
  end

  @doc """
  Wraps both a value and a raw log into the Writer context.

  ## Example

      iex> writer = Funx.Monad.Writer.writer({:ok, [:step1, :step2]})
      iex> result = Funx.Monad.Writer.run(writer)
      iex> result.value
      :ok
      iex> result.log
      [:step1, :step2]
  """
  @spec writer({a, term()}) :: t(a) when a: term()
  def writer({value, log}) do
    %__MODULE__{
      writer: fn monoid ->
        wrapped = wrap(monoid, log)
        combined = append(monoid, wrapped)
        {value, combined}
      end
    }
  end

  @doc """
  Appends a log value using the monoid, returning `:ok` as the result.

  ## Example

      iex> writer = Funx.Monad.Writer.tell([:event])
      iex> result = Funx.Monad.Writer.run(writer)
      iex> result.value
      :ok
      iex> result.log
      [:event]
  """
  @spec tell(log) :: t(:ok) when log: term()
  def tell(raw_log) do
    %__MODULE__{
      writer: fn monoid ->
        wrapped = wrap(monoid, raw_log)
        combined = append(monoid, wrapped)
        {:ok, combined}
      end
    }
  end

  @doc """
  Captures the current log and returns it alongside the result.

  The log remains unchanged—only the result is modified to include it.

  ## Example

      iex> writer = Funx.Monad.Writer.writer({"done", [:start, :finish]})
      iex> listened = Funx.Monad.Writer.listen(writer)
      iex> result = Funx.Monad.Writer.run(listened)
      iex> result.value
      {"done", [:start, :finish]}
      iex> result.log
      [:start, :finish]
  """
  @spec listen(t(a)) :: t({a, log}) when a: term(), log: term()
  def listen(%__MODULE__{writer: writer_fn}) do
    %__MODULE__{
      writer: fn monoid ->
        {value, new_monoid} = writer_fn.(monoid)
        {{value, unwrap(new_monoid)}, new_monoid}
      end
    }
  end

  @doc """
  Transforms the final log by applying a function to it.

  The result remains unchanged—only the log is modified.

  ## Example

      iex> writer = Funx.Monad.Writer.writer({"ok", [:a, :b]})
      iex> censored = Funx.Monad.Writer.censor(writer, fn log -> Enum.reverse(log) end)
      iex> result = Funx.Monad.Writer.run(censored)
      iex> result.value
      "ok"
      iex> result.log
      [:b, :a]
  """
  @spec censor(t(a), (term() -> term())) :: t(a) when a: term()
  def censor(%__MODULE__{writer: writer_fn}, f) do
    %__MODULE__{
      writer: fn monoid ->
        {value, final_monoid} = writer_fn.(monoid)
        unwrapped = unwrap(final_monoid)
        modified = f.(unwrapped)
        {value, wrap(final_monoid, modified)}
      end
    }
  end

  @doc """
  Applies a log-transforming function that is returned from within the computation.

  This allows the result of a computation to include not only a value, but also
  a function that modifies the final accumulated log.

  The input to `pass/1` must be a Writer containing a tuple `{result, f}`, where
  `f` is a function from log to log. This function will be applied to the final log
  just before it's returned.

  ## Example

      iex> result =
      ...>   Funx.Monad.Writer.pure({"done", fn log -> log ++ [:transformed] end})
      ...>   |> Funx.Monad.Writer.pass()
      ...>   |> Funx.Monad.Writer.run()
      iex> result.value
      "done"
      iex> result.log
      [:transformed]
  """
  @spec pass(t({a, (log -> log)})) :: t(a) when a: term(), log: term()
  def pass(%Writer{writer: writer_fn}) do
    %Writer{
      writer: fn monoid ->
        {{value, f}, monoid1} = writer_fn.(monoid)
        {value, wrap(monoid1, f.(unwrap(monoid1)))}
      end
    }
  end

  @doc """
  Executes the Writer and returns both the result and the final accumulated log.

  By default, it uses `ListConcat` unless a monoid is explicitly passed.

  ## Example

      iex> writer = Funx.Monad.Writer.writer({"ok", [:a, :b]})
      iex> result = Funx.Monad.Writer.run(writer)
      iex> result.value
      "ok"
      iex> result.log
      [:a, :b]
  """
  @spec run(t(a), monoid) :: Writer.Result.t(a, log)
        when a: term(), log: term(), monoid: term()

  def run(%__MODULE__{writer: writer_fn}, monoid \\ %ListConcat{}) do
    {result, final_monoid} = writer_fn.(monoid)
    %Writer.Result{value: result, log: unwrap(final_monoid)}
  end

  @doc """
  Executes the Writer and returns only the final accumulated log.

  Uses `ListConcat` by default.

  ## Example

      iex> writer =
      ...>   Funx.Monad.Writer.writer({:ok, [:step1]})
      ...>   |> Funx.Monad.bind(fn _ -> Funx.Monad.Writer.tell([:step2]) end)
      iex> Funx.Monad.Writer.exec(writer)
      [:step1, :step2]
  """
  @spec exec(t(a), monoid) :: log when a: term(), monoid: term(), log: term()
  def exec(%__MODULE__{writer: writer_fn}, monoid \\ %ListConcat{}) do
    {_value, final_monoid} = writer_fn.(monoid)
    unwrap(final_monoid)
  end

  @doc """
  Executes the Writer and returns only the final result value.

  Uses `ListConcat` by default.

  ## Example

      iex> writer =
      ...>   Funx.Monad.Writer.writer({10, [:init]})
      ...>   |> Funx.Monad.bind(fn x ->
      ...>     Funx.Monad.Writer.tell([:logged])
      ...>     |> Funx.Monad.bind(fn _ -> Funx.Monad.Writer.pure(x * 2) end)
      ...>   end)
      iex> Funx.Monad.Writer.eval(writer)
      20
  """
  @spec eval(t(a), monoid) :: a when a: term(), monoid: term()
  def eval(%__MODULE__{writer: writer_fn}, monoid \\ %ListConcat{}) do
    {value, _final_monoid} = writer_fn.(monoid)
    value
  end
end

defimpl Funx.Monad, for: Funx.Monad.Writer do
  alias Funx.Monad.Writer

  @spec map(Writer.t(a), (a -> b)) :: Writer.t(b) when a: term(), b: term()
  def map(%Writer{writer: writer_fn}, func) do
    %Writer{
      writer: fn monoid ->
        {value, new_monoid} = writer_fn.(monoid)
        {func.(value), new_monoid}
      end
    }
  end

  @spec bind(Writer.t(a), (a -> Writer.t(b))) :: Writer.t(b) when a: term(), b: term()
  def bind(%Writer{writer: writer1}, func) do
    %Writer{
      writer: fn monoid ->
        {value1, monoid1} = writer1.(monoid)
        %Writer{writer: writer2} = func.(value1)
        writer2.(monoid1)
      end
    }
  end

  @spec ap(Writer.t((a -> b)), Writer.t(a)) :: Writer.t(b) when a: term(), b: term()
  def ap(%Writer{writer: wf}, %Writer{writer: wx}) do
    %Writer{
      writer: fn monoid ->
        {f, monoid1} = wf.(monoid)
        {x, monoid2} = wx.(monoid1)
        {f.(x), monoid2}
      end
    }
  end
end

defimpl Funx.Tappable, for: Funx.Monad.Writer do
  alias Funx.Monad.Writer

  @spec tap(Writer.t(a), (a -> any())) :: Writer.t(a) when a: term()
  def tap(%Writer{writer: writer_fn}, func) when is_function(func, 1) do
    %Writer{
      writer: fn monoid ->
        {value, new_monoid} = writer_fn.(monoid)
        func.(value)
        {value, new_monoid}
      end
    }
  end
end
