defmodule Funx.Macros do
  @moduledoc """
  Provides macros for automatically implementing `Funx.Eq` and `Funx.Ord` protocols
  for a given struct based on a specified field.

  These macros simplify the process of defining equality and ordering behaviors
  for custom structs by leveraging an existing field's comparison operations.
  """

  @doc """
  Generates an implementation of the `Funx.Eq` protocol for the given struct,
  using the specified field as the basis for equality comparison.

  ## Examples

      defmodule Person do
        defstruct [:name, :age]
      end

      require Funx.Macros
      Funx.Macros.eq_for(Person, :age)

      iex> Eq.eq?(%Person{age: 30}, %Person{age: 30})
      true

      iex> Eq.eq?(%Person{age: 25}, %Person{age: 30})
      false
  """
  defmacro eq_for(for_struct, field) do
    quote do
      alias Funx.Eq

      defimpl Funx.Eq, for: unquote(for_struct) do
        def eq?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Eq.eq?(v1, v2)

        def not_eq?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Eq.not_eq?(v1, v2)
      end
    end
  end

  @doc """
  Generates an implementation of the `Funx.Ord` protocol for the given struct,
  using the specified field as the basis for ordering comparisons.

  ## Examples

      defmodule Person do
        defstruct [:name, :age]
      end

      require Funx.Macros
      Funx.Macros.ord_for(Person, :age)

      iex> Ord.lt?(%Person{age: 25}, %Person{age: 30})
      true

      iex> Ord.gt?(%Person{age: 35}, %Person{age: 30})
      true
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro ord_for(for_struct, field) do
    quote do
      alias Funx.Ord

      defimpl Funx.Ord, for: unquote(for_struct) do
        def lt?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.lt?(v1, v2)

        def lt?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ < b.__struct__

        def le?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.le?(v1, v2)

        def le?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ <= b.__struct__

        def gt?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.gt?(v1, v2)

        def gt?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ > b.__struct__

        def ge?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.ge?(v1, v2)

        def ge?(%unquote(for_struct){} = a, b) when is_struct(b),
          do: a.__struct__ >= b.__struct__
      end
    end
  end
end
