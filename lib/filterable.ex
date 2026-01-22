defprotocol Funx.Filterable do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Ffilterable%2Ffilterable.livemd)

  The `Funx.Filterable` protocol defines functions for conditionally retaining or discarding
  values within a context. It generalizes the concepts of `filter`, `filter_map`, and `guard`
  across different data structures like `Maybe`, `List`, and others.

  These functions enable conditional value retention, transformation, and short-circuiting based
  on boolean conditions or predicate functions.
  """

  @doc """
  Conditionally retains a value within the context. If the boolean is true, returns the existing value;
  otherwise, returns an empty value for the context.

  ## Parameters:
  - `structure`: The context-wrapped value (e.g., `Just`, list, etc.).
  - `bool`: A boolean indicating whether to retain the value.

  ## Examples

      iex> Funx.Filterable.guard(Funx.Monad.Maybe.just(42), true)
      %Funx.Monad.Maybe.Just{value: 42}

      iex> Funx.Filterable.guard(Funx.Monad.Maybe.just(42), false)
      %Funx.Monad.Maybe.Nothing{}

      iex> Funx.Filterable.guard(Funx.Monad.Maybe.nothing(), true)
      %Funx.Monad.Maybe.Nothing{}
  """
  def guard(structure, bool)

  @doc """
  Retains values that satisfy the given predicate.

  The `filter/2` function applies a predicate to the value(s) inside the context. If the predicate returns `true`,
  the value is retained; otherwise, it is discarded. For collections, it filters all elements based on the predicate.

  ## Parameters:
  - `structure`: The context-wrapped value or collection.
  - `predicate`: A function `(a -> boolean)` determining whether to retain each value.

  ## Examples

      iex> Funx.Filterable.filter(Funx.Monad.Maybe.just(5), &(&1 > 3))
      %Funx.Monad.Maybe.Just{value: 5}

      iex> Funx.Filterable.filter(Funx.Monad.Maybe.just(2), &(&1 > 3))
      %Funx.Monad.Maybe.Nothing{}
  """
  def filter(structure, predicate)

  @doc """
  Applies a function that returns a `Maybe` value, combining filtering and mapping in a single pass.

  `filter_map/2` applies the provided function to the value(s) within the context. If the function returns `Just`,
  the transformed value is retained; if it returns `Nothing`, the value is discarded. This avoids multiple traversals
  when both mapping and filtering are required.

  ## Parameters:
  - `structure`: The context-wrapped value or collection.
  - `func`: A function `(a -> Maybe b)` that both transforms and conditionally retains values.

  ## Examples

      iex> Funx.Filterable.filter_map(Funx.Monad.Maybe.just(5), fn x -> if x > 3, do: Funx.Monad.Maybe.just(x * 2), else: Funx.Monad.Maybe.nothing() end)
      %Funx.Monad.Maybe.Just{value: 10}

      iex> Funx.Filterable.filter_map(Funx.Monad.Maybe.just(2), fn x -> if x > 3, do: Funx.Monad.Maybe.just(x * 2), else: Funx.Monad.Maybe.nothing() end)
      %Funx.Monad.Maybe.Nothing{}
  """
  def filter_map(structure, func)
end
