defmodule Monex.Reader do
  @moduledoc """
  The `Monex.Reader` module provides an implementation of the Reader monad,
  which allows for dependency injection by passing a shared environment to functions.

  The `Reader` monad enables defining computations that read from an environment without
  explicitly passing the environment around, supporting mapping, binding, and function application.
  """

  @type t(env, value) :: %__MODULE__{run: (env -> value)}

  defstruct [:run]

  @doc """
  Wraps a value in a `Reader`, producing a function that ignores the environment
  and always returns the given value.

  ## Examples

      iex> reader = Monex.Reader.pure(42)
      iex> Monex.Reader.run(reader, %{})
      42
  """
  @spec pure(value :: A) :: t(any(), A) when A: var
  def pure(value), do: %__MODULE__{run: fn _env -> value end}

  @doc """
  Runs the `Reader` with the provided environment, returning the computed value.

  ## Examples

      iex> reader = Monex.Reader.pure(42)
      iex> Monex.Reader.run(reader, %{})
      42
  """
  @spec run(t(Env, A), Env) :: A when Env: var, A: var
  def run(%__MODULE__{run: f}, env), do: f.(env)

  @doc """
  Creates a `Reader` that retrieves the current environment.

  ## Examples

      iex> reader = Monex.Reader.ask()
      iex> Monex.Reader.run(reader, %{foo: "bar"})
      %{foo: "bar"}
  """
  @spec ask() :: t(Env, Env) when Env: var
  def ask, do: %__MODULE__{run: fn env -> env end}

  @doc """
  Creates a `Reader` that applies a function to the environment, returning the result.

  ## Examples

      iex> reader = Monex.Reader.asks(fn env -> Map.get(env, :foo) end)
      iex> Monex.Reader.run(reader, %{foo: "bar"})
      "bar"
  """
  @spec asks(func :: (Env -> A)) :: t(Env, A) when Env: var, A: var
  def asks(func), do: %__MODULE__{run: func}

  defimpl Monex.Monad do
    alias Monex.Reader

    @doc """
    Binds a `Reader` to a function, allowing chained computations within the Reader context.

    ## Examples

        iex> reader = Monex.Reader.pure(10)
        iex> bound_reader = Monex.Monad.bind(reader, fn x -> Monex.Reader.pure(x + 5) end)
        iex> Monex.Reader.run(bound_reader, %{})
        15
    """
    @spec bind(Reader.t(Env, A), (A -> Reader.t(Env, B))) :: Reader.t(Env, B)
          when Env: var, A: var, B: var
    def bind(%Reader{run: f}, func),
      do: %Reader{run: fn env -> func.(f.(env)).run.(env) end}

    @doc """
    Applies a function contained within one `Reader` to the value within another `Reader`.

    ## Examples

        iex> func_reader = Monex.Reader.pure(fn x -> x * 2 end)
        iex> value_reader = Monex.Reader.pure(10)
        iex> result_reader = Monex.Monad.ap(func_reader, value_reader)
        iex> Monex.Reader.run(result_reader, %{})
        20
    """
    @spec ap(Reader.t(Env, (A -> B)), Reader.t(Env, A)) :: Reader.t(Env, B)
          when Env: var, A: var, B: var
    def ap(%Reader{run: f_func}, %Reader{run: f_value}),
      do: %Reader{run: fn env -> f_func.(env).(f_value.(env)) end}

    @doc """
    Maps a function over the result of a `Reader`, producing a new `Reader` with the transformed value.

    ## Examples

        iex> reader = Monex.Reader.pure(10)
        iex> mapped_reader = Monex.Monad.map(reader, fn x -> x * 2 end)
        iex> Monex.Reader.run(mapped_reader, %{})
        20
    """
    @spec map(Reader.t(Env, A), (A -> B)) :: Reader.t(Env, B)
          when Env: var, A: var, B: var
    def map(%Reader{run: f}, func), do: %Reader{run: fn env -> func.(f.(env)) end}
  end
end
