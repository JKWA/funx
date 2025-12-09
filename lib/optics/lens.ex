defmodule Funx.Optics.Lens do
  @moduledoc """
  A strictly lawful total optic that focuses on a part of a data structure.

  ## What "Total" Means

  A lens is **total**: it assumes the focus always exists within the valid domain.
  This is a contract enforced at runtime by raising `KeyError` when violated.

  Both `view!` and `set!` enforce totality symmetrically for all data types (maps,
  structs, etc.). If either operation can succeed when the focus is missing, you
  no longer have a lens: you have a prism, traversal, or optional.

  **If the focus might not exist, use a prism instead.**

  ## Core Operations

    * `view!/2` - Extracts the focused part (raises `KeyError` if missing)
    * `set!/3` - Updates the focused part (raises `KeyError` if missing)

  ## Composition

  Lenses compose naturally. Composing two lenses yields a new lens that
  focuses through both layers sequentially.

  ## Monoid Structure

  Lenses form a monoid under composition **for a fixed outer type `s`**.

  The monoid structure is provided via `Funx.Monoid.LensCompose`, which wraps
  lenses for use with generic monoid operations:

  - **Identity**: `make(fn s -> s end, fn _s, a -> a end)` - the identity lens
  - **Operation**: `compose/2` - sequential composition

  You can use `concat/1` to compose multiple lenses sequentially, or work
  directly with `Funx.Monoid.LensCompose` for more control.

  ## Examples

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.key(:age)
      iex> %{age: 40} |> Lens.view!(lens)
      40
      iex> %{age: 40} |> Lens.set!(lens, 50)
      %{age: 50}

  Composing lenses for nested access:

      iex> alias Funx.Optics.Lens
      iex> outer = Lens.key(:profile)
      iex> inner = Lens.key(:score)
      iex> lens = Lens.compose(outer, inner)
      iex> %{profile: %{score: 12}} |> Lens.view!(lens)
      12
      iex> %{profile: %{score: 12}} |> Lens.set!(lens, 99)
      %{profile: %{score: 99}}

  Deeply nested composition with `concat/1`:

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.concat([Lens.key(:stats), Lens.key(:wins)])
      iex> %{stats: %{wins: 7}} |> Lens.view!(lens)
      7
      iex> %{stats: %{wins: 7}} |> Lens.set!(lens, 8)
      %{stats: %{wins: 8}}
  """

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Monoid.LensCompose

  @type viewer(s, a) :: (s -> a)
  @type updater(s, a) :: (s, a -> s)

  @type t(s, a) :: %__MODULE__{
          view: viewer(s, a),
          update: updater(s, a)
        }

  @type t :: t(any, any)

  defstruct [:view, :update]

  @spec make(viewer(s, a), updater(s, a)) :: t(s, a)
        when s: term(), a: term()
  def make(viewer, updater)
      when is_function(viewer, 1) and is_function(updater, 2) do
    %__MODULE__{view: viewer, update: updater}
  end

  @spec view!(s, t(s, a)) :: a
        when s: term(), a: term()
  def view!(s, %__MODULE__{view: v}) do
    v.(s)
  end

  @spec set!(s, t(s, a), a) :: s
        when s: term(), a: term()
  def set!(s, %__MODULE__{update: updater}, a) do
    updater.(s, a)
  end

  @doc """
  Composes two lenses. The outer lens focuses first, then the inner lens
  focuses within the result.

  This delegates to the monoid append operation, which contains the
  canonical composition logic.

      iex> alias Funx.Optics.Lens
      iex> outer = Lens.key(:profile)
      iex> inner = Lens.key(:age)
      iex> lens = Lens.compose(outer, inner)
      iex> %{profile: %{age: 30}} |> Lens.view!(lens)
      30
  """
  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    m_append(%LensCompose{}, outer, inner)
  end

  @doc """
  Composes a list of lenses into a single lens using sequential composition.

  Uses `Funx.Monoid.LensCompose` to leverage the generic monoid machinery,
  similar to `Funx.Optics.Prism.concat/1` for prisms.

  **Sequential semantics:**
  - On `view!`: Applies each lens's viewer in sequence (function composition)
  - On `set!`: Updates through each lens in reverse order to maintain structure

  This is sequential focusing through nested structures.

      iex> lenses = [
      ...>   Funx.Optics.Lens.key(:user),
      ...>   Funx.Optics.Lens.key(:profile),
      ...>   Funx.Optics.Lens.key(:age)
      ...> ]
      iex> lens = Funx.Optics.Lens.concat(lenses)
      iex> %{user: %{profile: %{age: 25}}} |> Funx.Optics.Lens.view!(lens)
      25
  """
  @spec concat([t()]) :: t()
  def concat(lenses) when is_list(lenses) do
    m_concat(%LensCompose{}, lenses)
  end

  @doc """
  Builds a lawful lens focusing on a single key in a map or struct.

  ## Contract

  The key **must exist** in the structure. When used with `view!` and `set!`,
  this lens uses `Map.fetch!/2` and `Map.replace!/3`, raising `KeyError` if
  the key is missing. This symmetric enforcement ensures all three lens laws hold.

  **If the key might not exist, use a prism instead.**

  ## Examples

      iex> lens = Funx.Optics.Lens.key(:name)
      iex> %{name: "Alice"} |> Funx.Optics.Lens.view!(lens)
      "Alice"
      iex> %{name: "Alice"} |> Funx.Optics.Lens.set!(lens, "Bob")
      %{name: "Bob"}

  With structs (preserves type):

      defmodule User, do: defstruct [:name, :age]
      lens = Funx.Optics.Lens.key(:name)
      user = %User{name: "Alice", age: 30}
      Funx.Optics.Lens.view!(user, lens) #=> "Alice"
      Funx.Optics.Lens.set!(user, lens, "Bob") #=> %User{name: "Bob", age: 30}
  """
  @spec key(atom) :: t(map(), term())
  def key(k) when is_atom(k) do
    make(
      fn m -> Map.fetch!(m, k) end,
      fn m, v -> Map.replace!(m, k, v) end
    )
  end

  @doc """
  Builds a lawful lens for nested map access by composing `key/1` lenses.

  This is equivalent to `concat(Enum.map(keys, &key/1))` and enforces totality
  at every level - raising `KeyError` when used with `view!` or `set!` if any
  intermediate key is missing.

  ## Examples

      iex> lens = Funx.Optics.Lens.path([:user, :profile, :name])
      iex> data = %{user: %{profile: %{name: "Alice"}}}
      iex> Funx.Optics.Lens.view!(data, lens)
      "Alice"
      iex> Funx.Optics.Lens.set!(data, lens, "Bob")
      %{user: %{profile: %{name: "Bob"}}}

  Raises on missing keys when accessed:

      iex> lens = Funx.Optics.Lens.path([:user, :name])
      iex> Funx.Optics.Lens.view!(%{}, lens)
      ** (KeyError) key :user not found in: %{}
  """
  @spec path([term()]) :: t(map(), term())
  def path(keys) when is_list(keys) do
    concat(Enum.map(keys, &key/1))
  end

  @doc """
  Updates the focused part of a structure by applying a function to it.

  This is the derived transformation operation for a lens. It is implemented
  as:

  - `view!/2` to extract the focused part
  - Application of the given function
  - `set!/3` to write the result back

  Because lenses are **total**, `over!/3` is also total. If the focus does not
  exist, a `KeyError` is raised by `view!/2` or `set!/3`.

  Only the focused part is changed. All other structure and data is preserved.

  ## Examples

      iex> lens = Funx.Optics.Lens.key(:age)
      iex> data = %{age: 40}
      iex> Funx.Optics.Lens.over!(data, lens, fn a -> a + 1 end)
      %{age: 41}

  Works through composed lenses:

      iex> outer = Funx.Optics.Lens.key(:profile)
      iex> inner = Funx.Optics.Lens.key(:score)
      iex> lens = Funx.Optics.Lens.compose(outer, inner)
      iex> data = %{profile: %{score: 10}}
      iex> Funx.Optics.Lens.over!(data, lens, fn s -> s * 2 end)
      %{profile: %{score: 20}}

  Works through `path/1`:

      iex> lens = Funx.Optics.Lens.path([:stats, :wins])
      iex> data = %{stats: %{wins: 3}}
      iex> Funx.Optics.Lens.over!(data, lens, fn n -> n + 5 end)
      %{stats: %{wins: 8}}
  """

  @spec over!(s, t(s, a), (a -> a)) :: s
        when s: term(), a: term()
  def over!(s, %__MODULE__{} = lens, f) when is_function(f, 1) do
    current = view!(s, lens)
    updated = f.(current)
    set!(s, lens, updated)
  end
end
