defprotocol Funx.Monad do
  @moduledoc """
  The `Funx.Monad` protocol defines the core monadic operations: `ap/2`, `bind/2`, and `map/2`.

  A monad is an abstraction that represents computations as a series of steps.
  This protocol is designed to be implemented by types that wrap a value and allow chaining of operations while preserving the wrapped context.

  ## Functions
  - `map/2`: Applies a function to the value within the monad.
  - `bind/2`: Chains operations by passing the unwrapped value into a function that returns another monad.
  - `ap/2`: Applies a monadic function to another monadic value.
  """
  @fallback_to_any true

  @type t() :: term()

  @doc """
  Applies a monadic function to another monadic value.

  The function `func` is expected to be wrapped in a monadic context and is applied to the value `m` within its own monadic context.
  The result is wrapped in the same context as the original monad.

  ## Examples

      iex> Funx.Monad.ap(Funx.Maybe.just(fn x -> x * 2 end), Funx.Maybe.just(3))
      %Funx.Maybe.Just{value: 6}

  In the case of `Nothing`:

      iex> Funx.Monad.ap(Funx.Maybe.nothing(), Funx.Maybe.just(3))
      %Funx.Maybe.Nothing{}
  """
  @spec ap(t(), t()) :: t()
  def ap(func, m)

  @doc """
  Chains a monadic operation.

  The `bind/2` function takes a monad `m` and a function `func`. The function `func` is applied to the unwrapped value of `m`,
  and must return another monad. The result is the new monad produced by `func`.

  This is the core operation that allows chaining of computations, with the value being passed from one function to the next in a sequence.

  ## Examples

      iex> Funx.Monad.bind(Funx.Maybe.just(5), fn x -> Funx.Maybe.just(x * 2) end)
      %Funx.Maybe.Just{value: 10}

  In the case of `Nothing`:

      iex> Funx.Monad.bind(Funx.Maybe.nothing(), fn _ -> Funx.Maybe.just(5) end)
      %Funx.Maybe.Nothing{}
  """
  @spec bind(t(), (term() -> t())) :: t()
  def bind(m, func)

  @doc """
  Maps a function over the value inside the monad.

  The `map/2` function takes a monad `m` and a function `func`, applies the function to the value inside `m`, and returns a new monad
  containing the result. The original monadic context is preserved.

  ## Examples

      iex> Funx.Monad.map(Funx.Maybe.just(2), fn x -> x + 3 end)
      %Funx.Maybe.Just{value: 5}

  In the case of `Nothing`:

      iex> Funx.Monad.map(Funx.Maybe.nothing(), fn x -> x + 3 end)
      %Funx.Maybe.Nothing{}
  """
  @spec map(t(), (term() -> term())) :: t()
  def map(m, func)
end

defimpl Funx.Monad, for: Any do
  @spec ap(any(), any()) :: any()
  def ap(func, value) when is_function(func, 1), do: func.(value)

  @spec bind(any(), (any() -> any())) :: any()
  def bind(value, func) when is_function(func, 1), do: func.(value)

  @spec map(any(), (any() -> any())) :: any()
  def map(value, func) when is_function(func, 1), do: func.(value)
end
