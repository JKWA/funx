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
      iex> Lens.get(lens, %{age: 40})
      40
      iex> Lens.set(lens, 50, %{age: 40})
      %{age: 50}

  Composing lenses:

      iex> alias Funx.Optics.Lens
      iex> outer = Lens.key(:profile)
      iex> inner = Lens.key(:score)
      iex> lens = Lens.compose(outer, inner)
      iex> Lens.get(lens, %{profile: %{score: 12}})
      12
      iex> Lens.set(lens, 99, %{profile: %{score: 12}})
      %{profile: %{score: 99}}

  Nested path lens:

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.path([:stats, :wins])
      iex> Lens.get(lens, %{stats: %{wins: 7}})
      7
      iex> Lens.set(lens, 8, %{stats: %{wins: 7}})
      %{stats: %{wins: 8}}
  """

  @type getter(s, a) :: (s -> a)
  @type setter(s, a) :: (a, s -> s)

  @type t(s, a) :: %__MODULE__{
          get: getter(s, a),
          set: setter(s, a)
        }

  defstruct [:get, :set]

  @spec make(getter(s, a), setter(s, a)) :: t(s, a)
        when s: term(), a: term()
  def make(getter, setter)
      when is_function(getter, 1) and is_function(setter, 2) do
    %__MODULE__{get: getter, set: setter}
  end

  @spec get(t(s, a), s) :: a
        when s: term(), a: term()
  def get(%__MODULE__{get: g}, s) do
    g.(s)
  end

  @spec set(t(s, a), a, s) :: s
        when s: term(), a: term()
  def set(%__MODULE__{set: sfun}, a, s) do
    sfun.(a, s)
  end

  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    make(
      fn s ->
        inner.get.(outer.get.(s))
      end,
      fn a, s ->
        inner_value = outer.get.(s)
        updated_inner = inner.set.(a, inner_value)
        outer.set.(updated_inner, s)
      end
    )
  end

  @spec key(atom) :: t(map(), term())
  def key(k) when is_atom(k) do
    make(
      fn m -> Map.get(m, k) end,
      fn v, m -> Map.put(m, k, v) end
    )
  end

  @spec path([term()]) :: t(map(), term())
  def path(keys) when is_list(keys) do
    make(
      fn m -> get_in(m, keys) end,
      fn v, m -> put_in(m, keys, v) end
    )
  end
end
