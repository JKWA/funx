defmodule Funx.Optics.Lens do
  @moduledoc """
  A total optic that focuses on a part of a data structure.

  ## What "Total" Means

  A lens is **total** in the categorical sense: it assumes the focus always
  exists within the valid domain. This is a *contract*, not a runtime guarantee.

  When the contract is violated (focus doesn't exist):
  - **Structs**: Both `view` and `set` raise (strict contract enforcement)
  - **Maps**: Both return/accept missing keys (permissive, for convenience)

  **The struct behavior is correct lens semantics**: Both operations enforce
  totality. If you allow silent failure or default construction, you are no
  longer implementing a lens - you would be implementing a different optic
  (prism, traversal, or optional).

  ## Core Operations

    * `view/2` - Extracts the focused part (total within domain)
    * `set/3` - Updates the focused part while preserving the rest (total within domain)

  ## Lenses vs Prisms

  **Lenses** are for *total* access with domain contracts:
  - **Contract**: The focus must exist
  - **On violation**: `set` raises (enforcing totality)
  - **Domain**: Struct fields, map keys guaranteed to exist
  - **Semantics**: Update in place, preserve structure

  **Prisms** are for *partial* access without domain contracts:
  - **Contract**: The focus may or may not exist
  - **On absence**: `preview` returns `Nothing` (not an error)
  - **Domain**: Optional values, variants, filtered data
  - **Semantics**: Construct from scratch, no preservation

  ## Lens Laws

  For any lens in its valid domain, these laws must hold:

  1. **Get-Put**: `set(s, view(s, lens), lens) == s`
     *(You get back what you put)*

  2. **Put-Get**: `view(set(s, a, lens), lens) == a`
     *(You can view what you just set)*

  3. **Put-Put**: `set(set(s, a1, lens), a2, lens) == set(s, a2, lens)`
     *(Second set wins)*

  These laws define what it means to be a lens. If your data violates the
  domain contract (missing key), you're outside the lens's domain, and the
  laws don't apply.

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
      iex> %{age: 40} |> Lens.view(lens)
      40
      iex> %{age: 40} |> Lens.set(50, lens)
      %{age: 50}

  Composing lenses:

      iex> alias Funx.Optics.Lens
      iex> outer = Lens.key(:profile)
      iex> inner = Lens.key(:score)
      iex> lens = Lens.compose(outer, inner)
      iex> %{profile: %{score: 12}} |> Lens.view(lens)
      12
      iex> %{profile: %{score: 12}} |> Lens.set(99, lens)
      %{profile: %{score: 99}}

  Nested path lens:

      iex> alias Funx.Optics.Lens
      iex> lens = Lens.path([:stats, :wins])
      iex> %{stats: %{wins: 7}} |> Lens.view(lens)
      7
      iex> %{stats: %{wins: 7}} |> Lens.set(8, lens)
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

  @spec view(s, t(s, a)) :: a
        when s: term(), a: term()
  def view(s, %__MODULE__{view: v}) do
    v.(s)
  end

  @spec set(s, a, t(s, a)) :: s
        when s: term(), a: term()
  def set(s, a, %__MODULE__{update: updater}) do
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
      iex> %{profile: %{age: 30}} |> Lens.view(lens)
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
  - On `view`: Applies each lens's viewer in sequence (function composition)
  - On `set`: Updates through each lens in reverse order to maintain structure

  This is sequential focusing through nested structures.

      iex> lenses = [
      ...>   Funx.Optics.Lens.key(:user),
      ...>   Funx.Optics.Lens.key(:profile),
      ...>   Funx.Optics.Lens.key(:age)
      ...> ]
      iex> lens = Funx.Optics.Lens.concat(lenses)
      iex> %{user: %{profile: %{age: 25}}} |> Funx.Optics.Lens.view(lens)
      25
  """
  @spec concat([t()]) :: t()
  def concat(lenses) when is_list(lenses) do
    m_concat(%LensCompose{}, lenses)
  end

  @doc """
  Builds a lens that focuses on a single key inside a map or struct.

  This lens works with both maps and structs, preserving the struct type
  when updating.

  ## Domain Contract

  The key must exist in the structure:
  - **Structs**: The field must be defined in the struct schema
  - **Maps**: The key must be present (for lawful behavior)

  ## Contract Enforcement

  **Structs** (strict, lawful lens):
  - `view`: Uses `Map.fetch!/2` - **raises `KeyError`** if field missing
  - `set`: Uses `Map.replace!/3` - **raises `KeyError`** if field missing
  - Both operations enforce the totality contract symmetrically

  **Maps** (permissive, for convenience):
  - `view`: Uses `Map.get/2` - returns value or `nil`
  - `set`: Uses `Map.put/3` - allows new keys
  - This is lawful only if the key is guaranteed to exist

  ## Why Structs Raise

  This is **not a bug**. A lens is total: it assumes the focus exists. When
  you use `view` or `set` on a missing struct field, you're violating the
  lens contract. The raise enforces that contract symmetrically on both
  operations. This is the correct behavior for a total optic.

  If you need to handle optional fields, use a prism instead.

  ## Examples

      iex> lens = Funx.Optics.Lens.key(:name)
      iex> %{name: "Alice"} |> Funx.Optics.Lens.view(lens)
      "Alice"
      iex> %{name: "Alice"} |> Funx.Optics.Lens.set("Bob", lens)
      %{name: "Bob"}

  With structs (preserves type, enforces totality):

      defmodule User, do: defstruct [:name, :age]
      lens = Funx.Optics.Lens.key(:name)
      user = %User{name: "Alice", age: 30}
      Funx.Optics.Lens.view(user, lens) #=> "Alice"
      Funx.Optics.Lens.set(user, "Bob", lens) #=> %User{name: "Bob", age: 30}

      # Using a non-existent field raises (correct lens behavior):
      # Funx.Optics.Lens.set(user, "x", Lens.key(:missing)) #=> ** (KeyError)
  """
  @spec key(atom) :: t(map(), term())
  def key(k) when is_atom(k) do
    make(
      fn m ->
        # Strict contract enforcement for structs, permissive for maps
        case m do
          %{__struct__: _} -> Map.fetch!(m, k)
          _ -> Map.get(m, k)
        end
      end,
      fn m, v ->
        # Preserve struct type and enforce totality
        case m do
          %{__struct__: _} -> Map.replace!(m, k, v)
          _ -> Map.put(m, k, v)
        end
      end
    )
  end

  @doc """
  Builds a lens that focuses on a nested path inside a map structure.

  **Warning**: This is a pragmatic lens, not a strictly lawful total lens.

  ## Behavior

  - `view`: Uses `get_in/2`, returns `nil` if any key in the path is missing
  - `set`: Uses `put_in/3`, which auto-vivifies intermediate maps

  ## Lawfulness Constraint

  This lens is only lawful when the complete path exists in the structure.
  If intermediate keys are missing:

  - `view` returns `nil`
  - `set` creates intermediate maps, which may not preserve the original structure

  This auto-vivification means `path/1` behaves more like a **traversal with
  default construction** than a pure total lens.

  ## When to Use

  Use `path/1` for:
  - Nested maps where the path is guaranteed to exist
  - Convenience when you want auto-vivification on `set`

  Avoid when:
  - You need strict lens laws
  - You want to distinguish "missing key" from "nil value"
  - You're working with structs (use composed `key/1` lenses instead)

  ## Examples

      iex> lens = Funx.Optics.Lens.path([:user, :profile, :name])
      iex> data = %{user: %{profile: %{name: "Alice"}}}
      iex> Funx.Optics.Lens.view(data, lens)
      "Alice"
      iex> Funx.Optics.Lens.set(data, "Bob", lens)
      %{user: %{profile: %{name: "Bob"}}}
  """
  @spec path([term()]) :: t(map(), term())
  def path(keys) when is_list(keys) do
    make(
      fn m -> get_in(m, keys) end,
      fn m, v -> put_in(m, keys, v) end
    )
  end
end
