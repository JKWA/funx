defmodule Funx.Macros do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmacros%2Fmacros.livemd)

  Provides macros for automatically implementing `Funx.Eq` and `Funx.Ord` protocols
  for structs based on field projections.

  The `Funx.Macros` module generates protocol implementations at compile time,
  eliminating boilerplate while providing flexible projection options for both
  equality and ordering comparisons. The macros support simple field access,
  nested structures, optional fields, and custom projections through a unified interface.

  This module is useful for:

    - Implementing `Funx.Eq` protocol for structs with projection-based equality
    - Implementing `Funx.Ord` protocol with various projection strategies
    - Handling optional fields with safe defaults via `or_else`
    - Accessing nested structures through Lens and Prism optics
    - Custom comparison logic via projection functions

  ## Macros

    - `eq_for/2` - Generate `Funx.Eq` protocol implementation (basic)
    - `eq_for/3` - Generate `Funx.Eq` protocol with options (e.g., `or_else`, `eq`)
    - `ord_for/2` - Generate `Funx.Ord` protocol implementation (basic)
    - `ord_for/3` - Generate `Funx.Ord` protocol with options (e.g., `or_else`)

  ## Projection Types

  Both `eq_for` and `ord_for` macros support multiple projection types, all normalized at compile time:

    - **Atom** - Converted to `Prism.key(atom)`. Safe for nil values with `Nothing < Just` semantics.
    - **Atom with or_else** - `ord_for(Struct, :field, or_else: default)` → `{Prism.key(:field), default}`.
    - **Lens** - Total access via `Lens.key/1` or `Lens.path/1`. Raises `KeyError` on missing keys.
    - **Prism** - Partial access via `Prism.key/1` or `Prism.path/1`. Returns `Maybe` with `Nothing < Just` semantics.
    - **Prism with or_else** - `ord_for(Struct, Prism.key(:field), or_else: default)` → `{prism, default}`.
    - **{Prism, default}** - Tuple syntax for partial access with explicit fallback value.
    - **Traversal** - Multiple foci via `Traversal.combine/1`. All foci must match for equality.
    - **Function** - Custom projection `fn x -> ... end` or `&fun/1`. Must return a comparable value.

  > Note: Atoms use Prism by default for safety. Use explicit `Lens.key(:field)` when you need
  > total access that raises on missing keys or nil intermediate values.

  ## or_else Option

  The `or_else` option provides fallback values for optional fields:

    - **Valid with:** Atoms, Prisms, and helper functions returning Prisms
    - **Invalid with:** Lens (always returns a value), Traversal (focuses on multiple elements),
      functions (must handle own defaults), struct literals, or `{Prism, default}` tuples (redundant)

  When `or_else` is used with an incompatible projection type, a clear compile-time
  error is raised with actionable guidance.

  ## Examples

  Simple equality by field:

      iex> defmodule Person do
      ...>   defstruct [:name, :age]
      ...>
      ...>   require Funx.Macros
      ...>   Funx.Macros.eq_for(Person, :age)
      ...> end
      iex> alias Funx.Eq
      iex> Eq.eq?(%Person{name: "Alice", age: 30}, %Person{name: "Bob", age: 30})
      true

  Equality with optional field:

      iex> defmodule Item do
      ...>   defstruct [:name, :score]
      ...>
      ...>   require Funx.Macros
      ...>   Funx.Macros.eq_for(Item, :score, or_else: 0)
      ...> end
      iex> alias Funx.Eq
      iex> i1 = %Item{name: "A", score: nil}
      iex> i2 = %Item{name: "B", score: 0}
      iex> Eq.eq?(i1, i2)  # nil becomes 0, so equal
      true

  Ordering by field with Prism (safe for nil):

      iex> defmodule Product do
      ...>   defstruct [:name, :rating]
      ...>
      ...>   require Funx.Macros
      ...>   Funx.Macros.ord_for(Product, :rating)
      ...> end
      iex> alias Funx.Ord
      iex> p1 = %Product{name: "Widget", rating: 4}
      iex> p2 = %Product{name: "Gadget", rating: 5}
      iex> Ord.lt?(p1, p2)
      true

  Optional field with or_else:

      iex> defmodule Item do
      ...>   defstruct [:name, :score]
      ...>
      ...>   require Funx.Macros
      ...>   Funx.Macros.ord_for(Item, :score, or_else: 0)
      ...> end
      iex> alias Funx.Ord
      iex> i1 = %Item{name: "A", score: nil}
      iex> i2 = %Item{name: "B", score: 10}
      iex> Ord.lt?(i1, i2)  # nil becomes 0, so 0 < 10
      true

  Nested structure access with Lens:

      iex> defmodule Address, do: defstruct [:city, :state]
      iex> defmodule Customer do
      ...>   defstruct [:name, :address]
      ...>
      ...>   require Funx.Macros
      ...>   alias Funx.Optics.Lens
      ...>   Funx.Macros.ord_for(Customer, Lens.path([:address, :city]))
      ...> end
      iex> alias Funx.Ord
      iex> c1 = %Customer{name: "Alice", address: %Address{city: "Austin", state: "TX"}}
      iex> c2 = %Customer{name: "Bob", address: %Address{city: "Boston", state: "MA"}}
      iex> Ord.lt?(c1, c2)  # "Austin" < "Boston"
      true

  Function projection:

      iex> defmodule Article do
      ...>   defstruct [:title, :content]
      ...>
      ...>   require Funx.Macros
      ...>   Funx.Macros.ord_for(Article, &String.length(&1.title))
      ...> end
      iex> alias Funx.Ord
      iex> a1 = %Article{title: "Short", content: "..."}
      iex> a2 = %Article{title: "Very Long Title", content: "..."}
      iex> Ord.lt?(a1, a2)  # length("Short") < length("Very Long Title")
      true

  ## Protocol Dispatch

  The generated `Ord` implementations leverage the `Funx.Ord` protocol for projected values.
  Any type implementing `Ord` can be used as a projection target:

      defmodule Priority do
        defstruct [:level]
      end

      defimpl Funx.Ord, for: Priority do
        def lt?(a, b), do: a.level < b.level
        def le?(a, b), do: a.level <= b.level
        def gt?(a, b), do: a.level > b.level
        def ge?(a, b), do: a.level >= b.level
      end

      defmodule Task do
        defstruct [:title, :priority]

        require Funx.Macros
        Funx.Macros.ord_for(Task, :priority)  # Uses Funx.Ord.Priority
      end

  ## Compile-Time Behavior

  All macros expand at compile time into direct protocol implementations with zero
  runtime overhead. The `ord_for` macro normalizes all projection types into one of
  four canonical forms that `Funx.Ord.contramap/2` accepts:

    1. `Lens.t()` - Bare Lens struct
    2. `Prism.t()` - Bare Prism struct (uses `Maybe.lift_ord`)
    3. `{Prism.t(), or_else}` - Prism with fallback value
    4. `(a -> b)` - Projection function

  Example expansion:

      Funx.Macros.ord_for(Product, :rating, or_else: 0)

  Compiles to:

      defimpl Funx.Ord, for: Product do
        defp __ord_map__ do
          Funx.Ord.contramap({Prism.key(:rating), 0})
        end

        def lt?(a, b) when is_struct(a, Product) and is_struct(b, Product) do
          __ord_map__().lt?.(a, b)
        end
        # ... other comparison functions
      end

  ## Error Handling

  The macros provide clear compile-time errors for invalid configurations:

    - Using `or_else` with Lens (total access doesn't need fallback)
    - Using `or_else` with functions (functions must handle own defaults)
    - Using `or_else` with `{Prism, default}` tuple (redundant)
    - Using `or_else` with struct literals (ambiguous semantics)

  All error messages include actionable guidance and examples of correct usage.
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Macros.Errors

  # ============================================================================
  # PUBLIC MACROS - Equality (eq_for/2)
  # ============================================================================

  @doc """
  Generates an implementation of the `Funx.Eq` protocol for the given struct,
  using the specified projection as the basis for equality comparison.

  ## Projection Types

  The macro supports the same projection types as `ord_for`:

  - **Atom** - Converted to `Prism.key(atom)`. Safe for nil values.
  - **Atom with or_else** - `eq_for(Struct, :field, or_else: default)` → `{Prism.key(:field), default}`.
  - **Lens** - Total access via `Lens.key/1` or `Lens.path/1`. Raises on missing values.
  - **Prism** - Partial access via `Prism.key/1` or `Prism.path/1`.
  - **Prism with or_else** - `eq_for(Struct, Prism.key(:field), or_else: default)` → `{prism, default}`.
  - **{Prism, default}** - Partial access with fallback value.
  - **Traversal** - Multiple foci via `Traversal.combine/1`. All foci must match.
  - **Function** - Custom projection function `(struct -> value)`.

  ## Options

  - `:or_else` - Fallback value for optional fields. Only valid with atoms and Prisms.
  - `:eq` - Custom Eq module or map for comparison. Defaults to `Funx.Eq`.

  ## Examples

      # Atom (backward compatible)
      defmodule Person do
        defstruct [:name, :age]
      end
      Funx.Macros.eq_for(Person, :age)

      # Atom with or_else
      Funx.Macros.eq_for(Person, :score, or_else: 0)

      # Lens - total access
      Funx.Macros.eq_for(Customer, Lens.path([:address, :city]))

      # Prism - partial access
      Funx.Macros.eq_for(Item, Prism.key(:rating))

      # Traversal - multiple foci
      Funx.Macros.eq_for(Person, Traversal.combine([Lens.key(:name), Lens.key(:age)]))

      # Function projection
      Funx.Macros.eq_for(Article, &String.length(&1.title))

      # Custom Eq module
      Funx.Macros.eq_for(Person, :name, eq: CaseInsensitiveEq)
  """
  defmacro eq_for(for_struct, projection, opts \\ []) do
    or_else = Keyword.get(opts, :or_else)
    custom_eq = Keyword.get(opts, :eq)
    projection_ast = normalize_projection(projection, or_else)
    eq_module_ast = custom_eq || quote(do: Funx.Eq.Protocol)

    quote do
      alias Funx.Eq
      alias Funx.Optics.Prism

      defimpl Funx.Eq.Protocol, for: unquote(for_struct) do
        # Private function to build the eq_map once at module compile time
        defp __eq_map__ do
          Funx.Eq.contramap(unquote(projection_ast), unquote(eq_module_ast))
        end

        def eq?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __eq_map__().eq?.(a, b)
        end

        def not_eq?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __eq_map__().not_eq?.(a, b)
        end
      end
    end
  end

  # ============================================================================
  # PUBLIC MACROS - Ordering (ord_for/2, ord_for/3)
  # ============================================================================

  @doc """
  Generates an implementation of the `Funx.Ord` protocol for the given struct,
  using the specified projection as the basis for ordering comparisons.

  ## Projection Types

  The macro supports multiple projection types:

  - **Atom** - Converted to `Prism.key(atom)`. Safe for nil values (Nothing < Just).
  - **Atom with or_else** - `ord_for(Struct, :field, or_else: default)` → `{Prism.key(:field), default}`.
  - **Lens** - Total access via `Lens.key/1` or `Lens.path/1`. Raises on missing values.
  - **Prism** - Partial access via `Prism.key/1` or `Prism.path/1`. Nothing < Just semantics.
  - **Prism with or_else** - `ord_for(Struct, Prism.key(:field), or_else: default)` → `{prism, default}`.
  - **{Prism, default}** - Partial access with fallback value for Nothing.
  - **Function** - Custom projection function `(struct -> comparable)`.

  ## Options

  - `:or_else` - Fallback value for optional fields. Only valid with atoms and Prisms.

  ## Examples

      # Atom - uses Prism.key (safe for nil)
      defmodule Product do
        defstruct [:name, :rating]
      end
      Funx.Macros.ord_for(Product, :rating)

      # Atom with or_else - provides default for nil values
      Funx.Macros.ord_for(Product, :rating, or_else: 0)

      # Lens - total access (raises on nil)
      defmodule Customer do
        defstruct [:name, :address]
      end
      Funx.Macros.ord_for(Customer, Lens.path([:address, :city]))

      # Prism - partial access
      Funx.Macros.ord_for(Item, Prism.key(:score))

      # Prism with or_else
      Funx.Macros.ord_for(Item, Prism.key(:score), or_else: 0)

      # Prism with default tuple (alternative to or_else)
      Funx.Macros.ord_for(Task, {Prism.key(:priority), 0})

      # Function projection
      Funx.Macros.ord_for(Article, &String.length(&1.title))
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro ord_for(for_struct, projection, opts \\ []) do
    or_else = Keyword.get(opts, :or_else)
    projection_ast = normalize_projection(projection, or_else)

    quote do
      alias Funx.Optics.Prism
      alias Funx.Ord

      defimpl Funx.Ord.Protocol, for: unquote(for_struct) do
        # Private function to build the ord_map once at module compile time
        defp __ord_map__ do
          Funx.Ord.contramap(unquote(projection_ast))
        end

        def lt?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __ord_map__().lt?.(a, b)
        end

        def lt?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ < b.__struct__

        def le?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __ord_map__().le?.(a, b)
        end

        def le?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ <= b.__struct__

        def gt?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __ord_map__().gt?.(a, b)
        end

        def gt?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ > b.__struct__

        def ge?(a, b)
            when is_struct(a, unquote(for_struct)) and is_struct(b, unquote(for_struct)) do
          __ord_map__().ge?.(a, b)
        end

        def ge?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ >= b.__struct__
      end
    end
  end

  # ============================================================================
  # PROJECTION NORMALIZATION (PRIVATE)
  # ============================================================================

  # Atom without or_else - convert to Prism.key (safe for nil values, Nothing < Just semantics)
  defp normalize_projection(atom, nil) when is_atom(atom) do
    quote do
      Prism.key(unquote(atom))
    end
  end

  # Atom with or_else - convert to {Prism.key, default}
  defp normalize_projection(atom, or_else) when is_atom(atom) and not is_nil(or_else) do
    quote do
      {Prism.key(unquote(atom)), unquote(or_else)}
    end
  end

  # Lens.key(...) - cannot use or_else with Lens
  defp normalize_projection(
         {{:., _, [{:__aliases__, _, [:Lens]}, :key]}, _, _} = lens_ast,
         or_else
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise ArgumentError, Errors.or_else_with_lens()
    end
  end

  # Lens.path(...) - cannot use or_else with Lens
  defp normalize_projection(
         {{:., _, [{:__aliases__, _, [:Lens]}, :path]}, _, _} = lens_ast,
         or_else
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise ArgumentError, Errors.or_else_with_lens()
    end
  end

  # Prism.key(...) - can use or_else
  defp normalize_projection(
         {{:., _, [{:__aliases__, _, [:Prism]}, :key]}, _, _} = prism_ast,
         or_else
       ) do
    if is_nil(or_else) do
      prism_ast
    else
      quote do
        {unquote(prism_ast), unquote(or_else)}
      end
    end
  end

  # Prism.path(...) - can use or_else
  defp normalize_projection(
         {{:., _, [{:__aliases__, _, [:Prism]}, :path]}, _, _} = prism_ast,
         or_else
       ) do
    if is_nil(or_else) do
      prism_ast
    else
      quote do
        {unquote(prism_ast), unquote(or_else)}
      end
    end
  end

  # Traversal.* (any Traversal function) - cannot use or_else
  defp normalize_projection(
         {{:., _, [{:__aliases__, _, [:Traversal]}, _]}, _, _} = traversal_ast,
         or_else
       ) do
    if is_nil(or_else) do
      traversal_ast
    else
      raise ArgumentError, Errors.or_else_with_traversal()
    end
  end

  # {Prism, default} tuple - cannot have additional or_else (redundant)
  defp normalize_projection({_prism_ast, _or_else_ast} = tuple, nil) do
    quote do
      unquote(tuple)
    end
  end

  defp normalize_projection({_prism_ast, _or_else_ast}, _extra_or_else) do
    raise ArgumentError, Errors.redundant_or_else()
  end

  # Captured function &fun/1 - cannot use or_else
  defp normalize_projection({:&, _, _} = fun_ast, or_else) do
    if is_nil(or_else) do
      fun_ast
    else
      raise ArgumentError, Errors.or_else_with_captured_function()
    end
  end

  # Anonymous function fn ... end - cannot use or_else
  defp normalize_projection({:fn, _, _} = fun_ast, or_else) do
    if is_nil(or_else) do
      fun_ast
    else
      raise ArgumentError, Errors.or_else_with_anonymous_function()
    end
  end

  # Struct literal (e.g., %Lens{...}) - cannot use or_else with Lens struct
  defp normalize_projection({:%, _, _} = struct_ast, or_else) do
    if is_nil(or_else) do
      struct_ast
    else
      raise ArgumentError, Errors.or_else_with_struct_literal()
    end
  end

  # Remote function call (Module.function()) - can use or_else (runtime check)
  defp normalize_projection({{:., _, _}, _, _} = call_ast, or_else) do
    if is_nil(or_else) do
      call_ast
    else
      # Runtime: if helper returns Lens, contramap will raise
      quote do
        {unquote(call_ast), unquote(or_else)}
      end
    end
  end

  # Local function call (function_name()) - pass through (already handled by remote call pattern or atom)
  defp normalize_projection({function_name, _, args} = call_ast, or_else)
       when is_atom(function_name) and is_list(args) do
    if is_nil(or_else) do
      call_ast
    else
      # Runtime: if helper returns Lens, contramap will raise
      quote do
        {unquote(call_ast), unquote(or_else)}
      end
    end
  end
end
