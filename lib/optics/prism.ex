defmodule Funx.Optics.Prism do
  @moduledoc """
  A prism focuses on a *branch* of a data structure. Unlike a lens, a prism
  is *partial*: the focus may or may not be present.

  A prism exposes two core operations:

    preview: attempts to extract the focused part, returning a `Maybe`
    review:  rebuilds the whole value from the focused part

  Prisms compose. Composing two prisms yields a new prism that attempts both
  matches in sequence.

  ## Examples

      iex> p = Funx.Optics.Prism.filter(&(&1 > 10))
      iex> 12 |> Funx.Optics.Prism.preview(p)
      %Funx.Monad.Maybe.Just{value: 12}
      iex> 5 |> Funx.Optics.Prism.preview(p)
      %Funx.Monad.Maybe.Nothing{}
      iex> 20 |> Funx.Optics.Prism.review(p)
      20
  """

  alias Funx.Monad.Maybe
  import Funx.Monad, only: [bind: 2]

  @type matcher(s, a) :: (s -> Maybe.t(a))
  @type builder(s, a) :: (a -> s)

  @type t(s, a) :: %__MODULE__{
          match: matcher(s, a),
          build: builder(s, a)
        }

  @type t :: t(any, any)

  defstruct [:match, :build]

  @doc """
  Creates a new prism from a matcher and a builder.

  The matcher attempts to extract the focused part, returning a `Maybe`.
  The builder reconstructs the whole structure from the focused part.

      iex> p =
      ...>   Funx.Optics.Prism.make(
      ...>     fn x -> Funx.Monad.Maybe.just(x) end,
      ...>     fn x -> x end
      ...>   )
      iex> Funx.Optics.Prism.preview(5, p)
      %Funx.Monad.Maybe.Just{value: 5}
  """
  @spec make(matcher(s, a), builder(s, a)) :: t(s, a)
        when s: term(), a: term()
  def make(match, build)
      when is_function(match, 1) and is_function(build, 1) do
    %__MODULE__{match: match, build: build}
  end

  @doc """
  Attempts to extract the focus from a structure using the prism.

  Returns a `Funx.Monad.Maybe.Just` on success or `Funx.Monad.Maybe.Nothing`
  if the branch does not match.

      iex> p = Funx.Optics.Prism.filter(& &1 > 0)
      iex> Funx.Optics.Prism.preview(3, p)
      %Funx.Monad.Maybe.Just{value: 3}
      iex> Funx.Optics.Prism.preview(-1, p)
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec preview(s, t(s, a)) :: Maybe.t(a)
        when s: term(), a: term()
  def preview(s, %__MODULE__{match: match}),
    do: match.(s)

  @doc """
  Reconstructs the whole structure from the focused part.

  Review reverses the prism, injecting the focused value back into
  the outer structure.

      iex> p = Funx.Optics.Prism.some()
      iex> Funx.Optics.Prism.review(10, p)
      [10]
  """
  @spec review(a, t(s, a)) :: s
        when s: term(), a: term()
  def review(a, %__MODULE__{build: build}),
    do: build.(a)

  @doc """
  Composes two prisms. The outer prism runs first; if it succeeds,
  the inner prism runs next.

      iex> p1 = Funx.Optics.Prism.filter(& &1 > 0)
      iex> p2 = Funx.Optics.Prism.filter(&(rem(&1, 2) == 0))
      iex> p = Funx.Optics.Prism.compose(p1, p2)
      iex> Funx.Optics.Prism.preview(4, p)
      %Funx.Monad.Maybe.Just{value: 4}
  """
  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    make(
      fn s ->
        outer.match.(s)
        |> bind(fn i -> inner.match.(i) end)
      end,
      fn a ->
        inner_value = inner.build.(a)
        outer.build.(inner_value)
      end
    )
  end

  @doc """
  A prism that focuses on the first element of a non-empty list.

  `preview` returns:

    %Funx.Monad.Maybe.Just{value: head}

  or:

    %Funx.Monad.Maybe.Nothing{}

  if the list is empty or not a list.

  `review` wraps a value into a single-element list.

      iex> p = Funx.Optics.Prism.some()
      iex> Funx.Optics.Prism.preview([1, 2, 3], p)
      %Funx.Monad.Maybe.Just{value: 1}
      iex> Funx.Optics.Prism.review(:x, p)
      [:x]
  """
  @spec some() :: t([a], a) when a: term()
  def some do
    make(
      fn
        [head | _] -> Maybe.just(head)
        _ -> Maybe.nothing()
      end,
      fn a -> [a] end
    )
  end

  @doc """
  A prism that never matches.

  `preview` always returns `Funx.Monad.Maybe.Nothing`.
  `review` always returns `nil`.

      iex> p = Funx.Optics.Prism.none()
      iex> Funx.Optics.Prism.preview("anything", p)
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec none() :: t(any, nil)
  def none do
    make(
      fn _ -> Maybe.nothing() end,
      fn _ -> nil end
    )
  end

  @doc """
  Builds a prism that succeeds only when the predicate returns true.

  `preview` uses `Maybe.lift_predicate/2`.
  `review` returns the value unchanged.

      iex> p = Funx.Optics.Prism.filter(& &1 > 10)
      iex> Funx.Optics.Prism.preview(12, p)
      %Funx.Monad.Maybe.Just{value: 12}
      iex> Funx.Optics.Prism.preview(5, p)
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec filter((a -> boolean())) :: t(a, a) when a: term()
  def filter(predicate) when is_function(predicate, 1) do
    make(
      fn s -> Maybe.lift_predicate(s, predicate) end,
      fn a -> a end
    )
  end

  @doc """
  Builds a prism that focuses on a single key inside a map.

  `preview` succeeds only when:

    * the input is a map
    * the key exists
    * the value is not nil

  Otherwise it returns `Nothing`.

  `review` returns a new map containing just that key.

      iex> p = Funx.Optics.Prism.key(:age)
      iex> Funx.Optics.Prism.preview(%{age: 40}, p)
      %Funx.Monad.Maybe.Just{value: 40}
      iex> Funx.Optics.Prism.preview(%{age: nil}, p)
      %Funx.Monad.Maybe.Nothing{}
      iex> Funx.Optics.Prism.review(50, p)
      %{age: 50}
  """

  @spec key(atom) :: t(map(), any)
  def key(k) when is_atom(k) do
    matcher = fn
      %{} = m ->
        m
        |> Map.get(k)
        |> Maybe.from_nil()

      _ ->
        Maybe.nothing()
    end

    builder = fn value ->
      %{k => value}
    end

    make(matcher, builder)
  end

  @doc """
  Builds a prism that focuses on a nested path inside a map.

  `preview` attempts to traverse the path safely:

    * returns `Just(value)` if the entire path exists and the value is non-nil
    * returns `Nothing` if any key is missing, an intermediate structure
      is not a map, or the final value is nil

  `review` reconstructs a nested map containing the given value.
  All missing intermediate maps are created automatically.

      iex> p = Funx.Optics.Prism.path([:a, :b])
      iex> Funx.Optics.Prism.preview(%{a: %{b: 5}}, p)
      %Funx.Monad.Maybe.Just{value: 5}
      iex> Funx.Optics.Prism.review(7, p)
      %{a: %{b: 7}}
  """
  @spec path([atom]) :: t(map(), any)
  def path(keys) when is_list(keys) do
    matcher = fn s ->
      case safe_get_path(s, keys) do
        {:ok, value} -> Maybe.just(value)
        :error -> Maybe.nothing()
      end
    end

    # Safe review / reconstruction
    builder = fn value ->
      safe_put_path(%{}, keys, value)
    end

    make(matcher, builder)
  end

  # -------------------------------------
  # Internal helpers
  # -------------------------------------

  # No keys → cannot match
  defp safe_get_path(_s, []), do: :error

  # Single key
  defp safe_get_path(s, [k]) when is_map(s) do
    case Map.fetch(s, k) do
      {:ok, value} when not is_nil(value) ->
        {:ok, value}

      _ ->
        :error
    end
  end

  # Single key but s is not a map → fail
  defp safe_get_path(_s, [_k]), do: :error

  # Nested path: continue if map and key exists
  defp safe_get_path(s, [k | rest]) when is_map(s) do
    case Map.fetch(s, k) do
      {:ok, next} ->
        safe_get_path(next, rest)

      :error ->
        :error
    end
  end

  # Nested path but s is not a map → fail
  defp safe_get_path(_s, _path), do: :error

  # No keys: replace entire structure
  defp safe_put_path(_s, [], value), do: value

  # Single key: put into map; treat nil as empty map
  defp safe_put_path(s, [k], value) do
    Map.put(s || %{}, k, value)
  end

  # Nested path: ensure intermediate maps exist
  defp safe_put_path(s, [k | rest], value) do
    s = s || %{}

    child = Map.get(s, k, %{})
    Map.put(s, k, safe_put_path(child, rest, value))
  end
end
