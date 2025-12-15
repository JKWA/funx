defmodule Funx.Optics.Prism do
  import Kernel, except: [struct: 1]

  @moduledoc """
  The `Funx.Optics.Prism` module provides a lawful partial optic for focusing on a branch of a data structure.

  A prism is **partial**: the focus may or may not be present. This makes prisms ideal for working with
  optional values, variants, and sum types. Unlike lenses, prisms never raise—they return `Maybe` instead.

  **When to use prisms vs lenses:**

    - **Prisms** (partial): Use for optional values, variants, sum types, missing map keys.
    - **Lenses** (total): Use for record fields, map keys that always exist.

  ### Constructors

    - `key/1`: Focuses on an optional key in a map.
    - `struct/1`: Focuses on a specific struct type (for sum types).
    - `path/1`: Focuses on nested paths through maps and structs.
    - `make/2`: Creates a custom prism from preview and review functions.

  ### Core Operations

    - `preview/2`: Attempts to extract the focus, returning `Just(value)` or `Nothing`.
    - `review/2`: Reconstructs the whole structure from the focused value.

  **Important:** `review` constructs a fresh structure from the focused value alone—it does not merge
  or preserve other fields. This is lawful prism behavior. If you need to update while preserving other
  fields, use a lens instead.

  ### Composition

    - `compose/2`: Composes two prisms sequentially (outer then inner).
    - `compose/1`: Composes a list of prisms into a single prism.

  Prisms compose naturally. Composing two prisms yields a new prism that attempts both matches in sequence,
  stopping at the first `Nothing`.

  ## Monoid Structure

  Prisms form a monoid under composition **for a fixed outer type `s`**.

  The monoid structure is provided via `Funx.Monoid.Optics.PrismCompose`, which wraps prisms
  for use with generic monoid operations:

    - **Identity**: `make(fn x -> Maybe.from_nil(x) end, fn x -> x end)` - the identity prism
    - **Operation**: `compose/2` - sequential composition

  You can use `compose/1` to compose multiple prisms sequentially, or work directly
  with `Funx.Monoid.Optics.PrismCompose` for more control.

  ## Examples

  Working with optional map keys:

      iex> name_prism = Funx.Optics.Prism.key(:name)
      iex> Funx.Optics.Prism.preview(%{name: "Alice"}, name_prism)
      %Funx.Monad.Maybe.Just{value: "Alice"}
      iex> Funx.Optics.Prism.preview(%{age: 30}, name_prism)
      %Funx.Monad.Maybe.Nothing{}

  Composing prisms for nested access:

      iex> outer = Funx.Optics.Prism.key(:person)
      iex> inner = Funx.Optics.Prism.key(:name)
      iex> composed = Funx.Optics.Prism.compose(outer, inner)
      iex> Funx.Optics.Prism.preview(%{person: %{name: "Alice"}}, composed)
      %Funx.Monad.Maybe.Just{value: "Alice"}
      iex> Funx.Optics.Prism.preview(%{person: %{age: 30}}, composed)
      %Funx.Monad.Maybe.Nothing{}

  Using `path/1` for convenient nested access:

      iex> person_name = Funx.Optics.Prism.path([:person, :name])
      iex> Funx.Optics.Prism.preview(%{person: %{name: "Alice"}}, person_name)
      %Funx.Monad.Maybe.Just{value: "Alice"}
  """

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Monad.Maybe
  alias Funx.Monoid.Optics.PrismCompose

  @type previewer(s, a) :: (s -> Maybe.t(a))
  @type reviewer(s, a) :: (a -> s)

  @type t(s, a) :: %__MODULE__{
          preview: previewer(s, a),
          review: reviewer(s, a)
        }

  @type t :: t(any, any)

  defstruct [:preview, :review]

  # ============================================================================
  # Constructors
  # ============================================================================

  @doc """
  Builds a prism that focuses on a single key inside a map.

  ## Examples

      iex> p = Funx.Optics.Prism.key(:name)
      iex> Funx.Optics.Prism.preview(%{name: "Alice"}, p)
      %Funx.Monad.Maybe.Just{value: "Alice"}
      iex> Funx.Optics.Prism.preview(%{age: 30}, p)
      %Funx.Monad.Maybe.Nothing{}
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
    unless function_exported?(mod, :__struct__, 0) do
      raise ArgumentError,
            "#{inspect(mod)} is not a struct module. " <>
              "Prism.struct/1 requires a module with defstruct."
    end

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
  - `Module` - A naked struct verification (checks type, no key access)
  - `{Module, :atom}` - A struct-typed key access (verifies struct type and accesses key)

  The syntax expands as follows:
  - `:key` → `key(:key)` - plain key access
  - `Module` → `struct(Module)` - struct type verification
  - `{Module, :key}` → `compose(struct(Module), key(:key))` - typed field access

  Modules are distinguished from plain keys using `function_exported?(atom, :__struct__, 0)`.

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

      # Struct-typed path using {Module, :key} syntax
      p2 = Prism.path([{Person, :bio}, {Bio, :age}])
      Prism.review(30, p2)
      #=> %Person{bio: %Bio{age: 30, location: nil}, name: nil}

      # Naked struct at end verifies final type
      p3 = Prism.path([:profile, Bio])
      Prism.preview(%{profile: %Bio{age: 30}}, p3)
      #=> Just(%Bio{age: 30, location: nil})

      # Naked struct at beginning verifies root type
      p4 = Prism.path([Person, :name])
      Prism.review("Alice", p4)
      #=> %Person{name: "Alice", bio: nil}

      # Mix naked structs with typed field syntax
      p5 = Prism.path([{Person, :bio}, Bio, :age])
      Prism.review(25, p5)
      #=> %Person{bio: %Bio{age: 25, location: nil}, name: nil}

      # Naked struct only (just type verification)
      p6 = Prism.path([Person])
      Prism.preview(%Person{name: "Bob"}, p6)
      #=> Just(%Person{name: "Bob", bio: nil})

  ## Implementation

  The `path/1` function composes prisms using `compose/1`:
  - `:key` → `[key(:key)]`
  - `Module` → `[struct(Module)]`
  - `{Mod, :key}` → `[struct(Mod), key(:key)]`

  This means `path` is just syntactic sugar for prism composition.

  ## Important

  - When using `{Module, :field}`, ensure `:field` exists in `Module`
  - Using non-existent fields may violate prism laws (Kernel.struct/2 silently drops invalid keys)
  - The tuple form `{Module, :key}` requires `Module` to be a struct module (raises otherwise)
  - Plain lowercase atoms like `:user` are always treated as keys, not struct modules
  """
  @spec path([atom | {module, atom}]) :: t(map(), any)
  def path(path) when is_list(path) do
    prisms =
      Enum.flat_map(path, fn
        {mod, key} when is_atom(mod) and is_atom(key) ->
          if function_exported?(mod, :__struct__, 0) do
            [struct(mod), key(key)]
          else
            raise ArgumentError,
                  "#{inspect(mod)} in {#{inspect(mod)}, #{inspect(key)}} is not a struct module"
          end

        atom when is_atom(atom) ->
          if function_exported?(atom, :__struct__, 0) do
            [struct(atom)]
          else
            [key(atom)]
          end

        invalid ->
          raise ArgumentError,
                "path/1 expects atoms or {Module, :key} tuples, got: #{inspect(invalid)}"
      end)

    compose(prisms)
  end

  @doc """
  Creates a custom prism from previewer and reviewer functions.

  The previewer attempts to extract the focused part, returning a `Maybe`.
  The reviewer reconstructs the whole structure from the focused part.

  Both functions must maintain the prism laws for the result to be lawful.

  ## Examples

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

  @doc false
  @spec identity() :: t()
  def identity do
    make(
      fn x -> Maybe.from_nil(x) end,
      fn x -> x end
    )
  end

  # ============================================================================
  # Core Operations
  # ============================================================================

  @doc """
  Attempts to extract the focus from a structure using the prism.

  Returns a `Funx.Monad.Maybe.Just` on success or `Funx.Monad.Maybe.Nothing`
  if the branch does not match.

  ## Examples

      iex> p = Funx.Optics.Prism.key(:name)
      iex> Funx.Optics.Prism.preview(%{name: "Alice"}, p)
      %Funx.Monad.Maybe.Just{value: "Alice"}
      iex> Funx.Optics.Prism.preview(%{age: 30}, p)
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

  **Note**: Cannot review with `nil` as it would violate prism laws (since
  `Just(nil)` is invalid).

  ## Examples

      iex> p = Funx.Optics.Prism.key(:name)
      iex> Funx.Optics.Prism.review("Alice", p)
      %{name: "Alice"}
  """
  @spec review(a, t(s, a)) :: s
        when s: term(), a: term()
  def review(nil, %__MODULE__{}) do
    raise ArgumentError,
          "Cannot review with nil. " <>
            "Prisms use Maybe, which doesn't allow nil values. " <>
            "This would violate prism laws: preview(review(nil)) should equal Just(nil), but Just(nil) is invalid."
  end

  def review(a, %__MODULE__{review: review}),
    do: review.(a)

  # ============================================================================
  # Composition
  # ============================================================================

  @doc """
  Composes prisms into a single prism using sequential composition.

  This delegates to the monoid append operation, which contains the
  canonical composition logic.

  ## Binary composition

  Composes two prisms. The outer prism runs first; if it succeeds,
  the inner prism runs next.

      iex> outer = Funx.Optics.Prism.key(:account)
      iex> inner = Funx.Optics.Prism.key(:name)
      iex> p = Funx.Optics.Prism.compose(outer, inner)
      iex> Funx.Optics.Prism.preview(%{account: %{name: "Alice"}}, p)
      %Funx.Monad.Maybe.Just{value: "Alice"}

  ## List composition

  Composes a list of prisms into a single prism using sequential composition.

  **Sequential semantics:**
  - On `preview`: Applies each prism's matcher in sequence (Kleisli composition),
    stopping at the first `Nothing`
  - On `review`: Applies each prism's builder in reverse order (function composition)

  This is **not** a union or choice operator. It does not "try all branches."
  It is strict sequential matching and construction.

      iex> prisms = [
      ...>   Funx.Optics.Prism.key(:account),
      ...>   Funx.Optics.Prism.key(:name)
      ...> ]
      iex> p = Funx.Optics.Prism.compose(prisms)
      iex> Funx.Optics.Prism.preview(%{account: %{name: "Alice"}}, p)
      %Funx.Monad.Maybe.Just{value: "Alice"}
      iex> Funx.Optics.Prism.preview(%{other: %{name: "Bob"}}, p)
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    m_append(%PrismCompose{}, outer, inner)
  end

  @spec compose([t()]) :: t()
  def compose(prisms) when is_list(prisms) do
    m_concat(%PrismCompose{}, prisms)
  end
end
