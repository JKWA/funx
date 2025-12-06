defmodule Funx.Optics.Lens do
  @moduledoc """
  A total optic that focuses on a part of a data structure. A lens provides
  two operations:

    get: extract the focused part from a structure
    set: replace the focused part within a structure

  A lens assumes that the focus exists. It is suitable for working with maps,
  structs, and nested structures where the accessed path is defined.

  Lenses compose. Composing two lenses yields a new lens that focuses through
  both layers.

  ## Examples

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.key(:age)
      iex> %{age: 40} |> Lens.get(lens)
      40
      iex> %{age: 40} |> Lens.set(50, lens)
      %{age: 50}

  Composing lenses:

      iex> alias Funx.Optics.Lens
      iex> outer = Lens.key(:profile)
      iex> inner = Lens.key(:score)
      iex> lens = Lens.compose(outer, inner)
      iex> %{profile: %{score: 12}} |> Lens.get(lens)
      12
      iex> %{profile: %{score: 12}} |> Lens.set(99, lens)
      %{profile: %{score: 99}}

  Nested path lens:

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.path([:stats, :wins])
      iex> %{stats: %{wins: 7}} |> Lens.get(lens)
      7
      iex> %{stats: %{wins: 7}} |> Lens.set(8, lens)
      %{stats: %{wins: 8}}
  """

  @type getter(s, a) :: (s -> a)
  @type setter(s, a) :: (s, a -> s)

  @type t(s, a) :: %__MODULE__{
          get: getter(s, a),
          set: setter(s, a)
        }

  @type t :: t(any, any)

  defstruct [:get, :set]

  @spec make(getter(s, a), setter(s, a)) :: t(s, a)
        when s: term(), a: term()
  def make(getter, setter)
      when is_function(getter, 1) and is_function(setter, 2) do
    %__MODULE__{get: getter, set: setter}
  end

  @spec get(s, t(s, a)) :: a
        when s: term(), a: term()
  def get(s, %__MODULE__{get: g}) do
    g.(s)
  end

  @spec set(s, a, t(s, a)) :: s
        when s: term(), a: term()
  def set(s, a, %__MODULE__{set: setter}) do
    setter.(s, a)
  end

  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    make(
      fn s ->
        s |> get(outer) |> get(inner)
      end,
      fn s, a ->
        inner_struct = get(s, outer)
        updated_inner = set(inner_struct, a, inner)
        set(s, updated_inner, outer)
      end
    )
  end

  @spec key(atom) :: t(map(), term())
  def key(k) when is_atom(k) do
    make(
      fn m -> Map.get(m, k) end,
      fn m, v -> Map.put(m, k, v) end
    )
  end

  @spec path([term()]) :: t(map(), term())
  def path(keys) when is_list(keys) do
    make(
      fn m -> get_in(m, keys) end,
      fn m, v -> put_in(m, keys, v) end
    )
  end
end
