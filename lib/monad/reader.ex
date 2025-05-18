defmodule Funx.Reader do
  @moduledoc """
  The `Funx.Reader` module represents the Reader monad, which allows computations to access
  shared, read-only environment values.

  This module defines core Reader functions:

    * `pure/1` – Lifts a value into the Reader context.
    * `run/2` – Executes the Reader with a given environment.
    * `asks/1` – Extracts and transforms a value from the environment.
    * `ask/0` – Extracts the full environment.

  This module implements the following protocol:

    * `Funx.Monad`: Implements `bind/2`, `map/2`, and `ap/2` for monadic composition.

  Note: The Reader monad does not implement `Eq` or `Ord`, since Readers are lazy— they do not actually contain a value until they are run. We only can compare the results of a Reader, not the Reader itself.

  """

  @type t(env, value) :: %__MODULE__{run: (env -> value)}

  @enforce_keys [:run]
  defstruct [:run]

  @doc """
  Lifts a value into the `Reader` context.

  ## Examples

      iex> reader = Funx.Reader.pure(42)
      iex> Funx.Reader.run(reader, %{})
      42
  """
  @spec pure(value :: A) :: t(any(), A) when A: var
  def pure(value), do: %__MODULE__{run: fn _env -> value end}

  @doc """
  Runs the `Reader` with the provided environment, returning the computed value.

  ## Examples

      iex> reader = Funx.Reader.pure(42)
      iex> Funx.Reader.run(reader, %{})
      42
  """
  @spec run(t(Env, A), Env) :: A when Env: var, A: var
  def run(%__MODULE__{run: f}, env), do: f.(env)

  @doc """
  Extracts and transforms the value contained in the environment, making it available within the Reader context.

  ## Examples

      iex> reader = Funx.Reader.asks(fn env -> Map.get(env, :foo) end)
      iex> Funx.Reader.run(reader, %{foo: "bar"})
      "bar"
  """

  @spec asks(func :: (Env -> A)) :: t(Env, A) when Env: var, A: var
  def asks(func), do: %__MODULE__{run: func}

  @doc """
  Extracts the value contained in the environment, making it available within the Reader context.

  ## Examples

      iex> reader = Funx.Reader.ask()
      iex> Funx.Reader.run(reader, %{foo: "bar"})
      %{foo: "bar"}
  """
  @spec ask() :: t(Env, Env) when Env: var
  def ask, do: asks(fn env -> env end)
end

defimpl Funx.Monad, for: Funx.Reader do
  alias Funx.Reader

  @spec map(Reader.t(Env, A), (A -> B)) :: Reader.t(Env, B)
        when Env: var, A: var, B: var
  def map(%Reader{run: f}, func), do: %Reader{run: fn env -> func.(f.(env)) end}

  @spec bind(Reader.t(Env, A), (A -> Reader.t(Env, B))) :: Reader.t(Env, B)
        when Env: var, A: var, B: var
  def bind(%Reader{run: f}, func),
    do: %Reader{run: fn env -> func.(f.(env)).run.(env) end}

  @spec ap(Reader.t(Env, (A -> B)), Reader.t(Env, A)) :: Reader.t(Env, B)
        when Env: var, A: var, B: var
  def ap(%Reader{run: f_func}, %Reader{run: f_value}),
    do: %Reader{run: fn env -> f_func.(env).(f_value.(env)) end}
end
