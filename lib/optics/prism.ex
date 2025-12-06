defmodule Funx.Optics.Prism do
  @moduledoc """
  A prism focuses on a branch of a data structure.

  Unlike a lens, a prism is *partial*: the focus may or may not be present.
  This makes prisms ideal for working with optional values, variants, and
  conditional structures.

  ## Core Operations

    * `preview/2` - Attempts to extract the focused part, returning `Maybe`
    * `review/2` - Rebuilds the whole value from the focused part

  ## Prisms vs Lenses

  **Prisms** are for *partial* access (the value may not be present):
  - `preview` may fail (returns `Maybe`)
  - `review` *reconstructs* from scratch (cannot preserve other fields)
  - Use for: optional values, variants, filtered data

  **Lenses** are for *total* access (the value is always present):
  - `view` always succeeds
  - `set` *updates* while preserving the rest of the structure
  - Use for: record fields, map keys that always exist

  ## Composition

  Prisms compose naturally. Composing two prisms yields a new prism that
  attempts both matches in sequence.

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

  Review reverses the prism, injecting the focused value back into the outer
  structure. **Important**: `review` constructs a fresh structure from the
  focused value alone - it does not merge with or patch an existing structure.
  This is the lawful behaviour of prisms.

  If you need to update a field while preserving other fields, you need a lens,
  not a prism.

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

  ## Preview

  Succeeds when the input is a map, the key exists, and the value is non-nil.
  Returns `Nothing` otherwise.

  ## Review

  Creates a map with the single key-value pair.

  ## Examples

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
    make(
      fn
        %{} = m -> m |> Map.get(k) |> Maybe.from_nil()
        _ -> Maybe.nothing()
      end,
      fn value -> %{k => value} end
    )
  end

  @doc """
  Builds a prism that focuses on a nested path inside a map or struct.

  ## Preview

  Traverses the path safely, returning `Just(value)` if the entire path exists
  and the value is non-nil. Returns `Nothing` if any key is missing, an
  intermediate value is not a map, or the final value is nil.

  **Note**: `nil` is treated as absence. If `nil` is a valid value in your domain,
  consider using a different optic.

  ## Review

  Constructs a fresh nested structure from the focused value. **Does not merge**
  with or preserve fields from an existing structure - this is lawful prism
  behaviour. Only the path specified is built; all other fields will be `nil`
  in structs or absent in maps.

  For updating existing structures while preserving other fields, use a lens
  instead.

  ## Options

    * `:structs` - List of struct modules for each path level. When provided,
      `review` creates struct instances instead of plain maps. The list length
      should match the path depth (one module per key). If struct validation
      fails, falls back to creating plain maps.

  ## Examples

      iex> p = Funx.Optics.Prism.path([:a, :b])
      iex> Funx.Optics.Prism.preview(%{a: %{b: 5}}, p)
      %Funx.Monad.Maybe.Just{value: 5}
      iex> Funx.Optics.Prism.review(7, p)
      %{a: %{b: 7}}

  With structs (constructs fresh struct, does not preserve other fields):

      defmodule User, do: defstruct [:name, :profile]
      defmodule Profile, do: defstruct [:age, :score]

      p = Funx.Optics.Prism.path([:profile, :age], structs: [User, Profile])
      Funx.Optics.Prism.review(30, p)
      #=> %User{name: nil, profile: %Profile{age: 30, score: nil}}
  """
  @spec path([atom], keyword()) :: t(map(), any)
  def path(keys, opts \\ []) when is_list(keys) do
    structs = Keyword.get(opts, :structs, [])

    make(
      fn s -> safe_get_path(s, keys) end,
      fn value ->
        if Enum.empty?(structs) do
          safe_put_path(%{}, keys, value)
        else
          build_struct_path_safe(keys, value, structs)
        end
      end
    )
  end

  ## Helpers for struct-aware path building

  defp build_struct_path_safe(keys, value, structs) do
    case build_struct_path_maybe(keys, value, structs) do
      {:ok, result} -> result
      :error -> safe_put_path(%{}, keys, value)
    end
  end

  defp build_struct_path_maybe([], value, _structs), do: {:ok, value}

  defp build_struct_path_maybe([k], value, [struct_mod | _]) do
    if Map.has_key?(struct_mod.__struct__(), k) do
      {:ok, struct(struct_mod, [{k, value}])}
    else
      :error
    end
  end

  defp build_struct_path_maybe([k], value, []), do: {:ok, %{k => value}}

  defp build_struct_path_maybe([k | rest], value, [struct_mod | rest_structs]) do
    cond do
      not Map.has_key?(struct_mod.__struct__(), k) ->
        :error

      Enum.empty?(rest_structs) and not Enum.empty?(rest) ->
        :error

      true ->
        with {:ok, child} <- build_struct_path_maybe(rest, value, rest_structs) do
          {:ok, struct(struct_mod, [{k, child}])}
        end
    end
  end

  defp build_struct_path_maybe([k | rest], value, []) do
    with {:ok, child} <- build_struct_path_maybe(rest, value, []) do
      {:ok, %{k => child}}
    end
  end

  ## Helpers for safe path traversal

  defp safe_get(m, k) when is_map(m) do
    case Map.fetch(m, k) do
      {:ok, v} -> Maybe.from_nil(v)
      :error -> Maybe.nothing()
    end
  end

  defp safe_get(_m, _k), do: Maybe.nothing()

  defp safe_get_path(_s, []), do: Maybe.nothing()

  defp safe_get_path(s, [k]), do: safe_get(s, k)

  defp safe_get_path(s, [k | rest]) do
    safe_get(s, k) |> bind(&safe_get_path(&1, rest))
  end

  ## Helpers for map-based path building
  ##
  ## Note: These functions are only called with plain maps (not structs),
  ## starting from an empty map %{}.

  defp safe_put_path(_map, [], value), do: value

  defp safe_put_path(map, [k], value) when is_map(map) do
    Map.put(map, k, value)
  end

  defp safe_put_path(map, [k | rest], value) when is_map(map) do
    child = Map.get(map, k, %{})
    Map.put(map, k, safe_put_path(child, rest, value))
  end
end
