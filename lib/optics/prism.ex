defmodule Funx.Optics.Prism do
  import Kernel, except: [struct: 1]

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

  ## Monoid Structure

  Prisms form a monoid under composition **for a fixed outer type `s`**.

  Without this constraint, `t(s, i)` and `t(i, a)` do not live in the same
  carrier set. The monoid exists within `{ t(s, x) for all x }`.

  The monoid structure is provided via `Funx.Monoid.PrismCompose`, which wraps
  prisms for use with generic monoid operations:

  - **Identity**: `filter(fn _ -> true end)` - accepts all values, `review` is identity
  - **Annihilator**: `none()` - rejects all values on `preview`, `review` returns `nil`
  - **Operation**: `compose/2` - sequential Kleisli composition on `preview`,
    function composition on `review`

  Note: This is not a symmetric monoid like numbers. The annihilator `none()`
  behaves asymmetrically: `preview` always fails, but `review` constructs `nil`.

  You can use `concat/1` to compose multiple prisms sequentially, or work
  directly with `Funx.Monoid.PrismCompose` for more control:

      iex> alias Funx.Optics.Prism
      iex> alias Funx.Monoid.PrismCompose
      iex> import Funx.Monoid
      iex> p1 = PrismCompose.new(Prism.filter(&(&1 > 0)))
      iex> p2 = PrismCompose.new(Prism.filter(&(rem(&1, 2) == 0)))
      iex> composed = append(p1, p2)
      iex> Prism.preview(4, PrismCompose.unwrap(composed))
      %Funx.Monad.Maybe.Just{value: 4}

  ## Examples

      iex> p = Funx.Optics.Prism.filter(&(&1 > 10))
      iex> 12 |> Funx.Optics.Prism.preview(p)
      %Funx.Monad.Maybe.Just{value: 12}
      iex> 5 |> Funx.Optics.Prism.preview(p)
      %Funx.Monad.Maybe.Nothing{}
      iex> 20 |> Funx.Optics.Prism.review(p)
      20
  """

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Monad.Maybe
  alias Funx.Monoid.PrismCompose

  @type previewer(s, a) :: (s -> Maybe.t(a))
  @type reviewer(s, a) :: (a -> s)

  @type t(s, a) :: %__MODULE__{
          preview: previewer(s, a),
          review: reviewer(s, a)
        }

  @type t :: t(any, any)

  defstruct [:preview, :review]

  @doc """
  Creates a new prism from a previewer and a reviewer.

  The previewer attempts to extract the focused part, returning a `Maybe`.
  The reviewer reconstructs the whole structure from the focused part.

      iex> p =
      ...>   Funx.Optics.Prism.make(
      ...>     fn x -> Funx.Monad.Maybe.just(x) end,
      ...>     fn x -> x end
      ...>   )
      iex> Funx.Optics.Prism.preview(5, p)
      %Funx.Monad.Maybe.Just{value: 5}
  """
  @spec make(previewer(s, a), reviewer(s, a)) :: t(s, a)
        when s: term(), a: term()
  def make(preview, review)
      when is_function(preview, 1) and is_function(review, 1) do
    %__MODULE__{preview: preview, review: review}
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
  def preview(s, %__MODULE__{preview: preview}),
    do: preview.(s)

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
  def review(a, %__MODULE__{review: review}),
    do: review.(a)

  @doc """
  Composes two prisms. The outer prism runs first; if it succeeds,
  the inner prism runs next.

  This delegates to the monoid append operation, which contains the
  canonical composition logic.

      iex> p1 = Funx.Optics.Prism.filter(& &1 > 0)
      iex> p2 = Funx.Optics.Prism.filter(&(rem(&1, 2) == 0))
      iex> p = Funx.Optics.Prism.compose(p1, p2)
      iex> Funx.Optics.Prism.preview(4, p)
      %Funx.Monad.Maybe.Just{value: 4}
  """
  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    m_append(%PrismCompose{}, outer, inner)
  end

  @doc """
  Composes a list of prisms into a single prism using sequential composition.

  Uses `Funx.Monoid.PrismCompose` to leverage the generic monoid machinery,
  similar to `Funx.Ord.Utils.concat/1` for comparators.

  **Sequential semantics:**
  - On `preview`: Applies each prism's matcher in sequence (Kleisli composition),
    stopping at the first `Nothing`
  - On `review`: Applies each prism's builder in reverse order (function composition)

  This is **not** a union or choice operator. It does not "try all branches."
  It is strict sequential matching and construction.

      iex> prisms = [
      ...>   Funx.Optics.Prism.filter(&(&1 > 0)),
      ...>   Funx.Optics.Prism.filter(&(rem(&1, 2) == 0)),
      ...>   Funx.Optics.Prism.filter(&(&1 < 100))
      ...> ]
      iex> p = Funx.Optics.Prism.concat(prisms)
      iex> Funx.Optics.Prism.preview(4, p)
      %Funx.Monad.Maybe.Just{value: 4}
      iex> Funx.Optics.Prism.preview(3, p)
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec concat([t()]) :: t()
  def concat(prisms) when is_list(prisms) do
    m_concat(%PrismCompose{}, prisms)
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
      &Funx.List.maybe_head/1,
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
  Builds a prism that focuses on a specific struct constructor.

  This prism succeeds only when the input value is a struct of the given module.
  It models a *sum-type constructor*: selecting one structural variant from a
  set of possible variants.

  On `review`, this prism can promote a plain map to the specified struct type,
  filling in defaults for missing fields.

  ## Examples

      # Given a struct module:
      defmodule Account do
        defstruct [:name, :email]
      end

      # Create a prism for that struct type
      p = Prism.struct(Account)

      # Preview succeeds for matching struct
      Prism.preview(%Account{name: "Alice"}, p)
      #=> %Just{value: %Account{name: "Alice", email: nil}}

      # Preview fails for non-matching types
      Prism.preview(%{name: "Bob"}, p)
      #=> %Nothing{}

      # Review promotes a map to the struct type
      Prism.review(%{name: "Charlie"}, p)
      #=> %Account{name: "Charlie", email: nil}

  ## Composition

  The `struct/1` prism is commonly composed with `key/1` to focus on struct fields:

      user_name = Prism.compose(Prism.struct(Account), Prism.key(:name))
      Prism.review("Alice", user_name)
      #=> %Account{name: "Alice", email: nil}
  """
  @spec struct(module()) :: t(struct(), struct())

  def struct(mod) when is_atom(mod) do
    make(
      fn
        %^mod{} = s -> Maybe.just(s)
        _ -> Maybe.nothing()
      end,
      fn
        %^mod{} = s -> s
        %{} = attrs -> Kernel.struct(mod, attrs)
      end
    )
  end

  @doc """
  Builds a prism that focuses on a nested path through maps and structs.

  Each element in the path can be:
  - `:atom` - A plain key access (works with maps and structs)
  - `{Module, :atom}` - A struct-typed key access (verifies struct type and accesses key)

  The `{Module, :atom}` syntax expands to `compose(struct(Module), key(:atom))`,
  which means:
  - On `preview`: verify the value is a `Module` struct, then extract the key
  - On `review`: construct a `Module` struct containing the nested value

  ## Examples

      # Plain map path
      p1 = Prism.path([:person, :bio, :age])
      Prism.review(30, p1)
      #=> %{person: %{bio: %{age: 30}}}

      # Given struct modules:
      defmodule Bio do
        defstruct [:age, :location]
      end

      defmodule Person do
        defstruct [:name, :bio]
      end

      # Struct-typed path
      p2 = Prism.path([{Person, :bio}, {Bio, :age}])
      Prism.review(30, p2)
      #=> %Person{bio: %Bio{age: 30, location: nil}, name: nil}

      # Mixed: struct at first level, plain key after
      p3 = Prism.path([{Person, :name}])
      Prism.review("Alice", p3)
      #=> %Person{name: "Alice", bio: nil}

  ## Implementation

  The `path/1` function composes prisms using `concat/1`:
  - `:key` → `[key(:key)]`
  - `{Mod, :key}` → `[struct(Mod), key(:key)]`

  This means `path` is just syntactic sugar for prism composition.

  ## Important

  When using `{Module, :field}`, ensure `:field` exists in `Module`.
  Using non-existent fields may violate prism laws due to how `Kernel.struct/2`
  silently drops invalid keys.
  """
  @spec path([atom | {module, atom}]) :: t(map(), any)
  def path(keys) when is_list(keys) do
    prisms =
      Enum.flat_map(keys, fn
        atom when is_atom(atom) ->
          [key(atom)]

        {mod, atom} when is_atom(mod) and is_atom(atom) ->
          [struct(mod), key(atom)]
      end)

    concat(prisms)
  end
end
