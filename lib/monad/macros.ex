defmodule Monex.Macros do
  @moduledoc """
  Provides macros for automatically implementing `Monex.Eq` and `Monex.Ord` protocols
  for a given struct based on a specified field.

  These macros simplify the process of defining equality and ordering behaviors
  for custom structs by leveraging an existing field's comparison operations.
  """

  @doc """
  Generates an implementation of the `Monex.Eq` protocol for the given struct,
  using the specified field as the basis for equality comparison.

  ## Examples

      defmodule Person do
        defstruct [:name, :age]
      end

      require Monex.Macros
      Monex.Macros.eq_for(Person, :age)

      iex> Eq.eq?(%Person{age: 30}, %Person{age: 30})
      true

      iex> Eq.eq?(%Person{age: 25}, %Person{age: 30})
      false
  """
  defmacro eq_for(for_struct, field) do
    quote do
      alias Monex.Eq

      defimpl Monex.Eq, for: unquote(for_struct) do
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
  Generates an implementation of the `Monex.Ord` protocol for the given struct,
  using the specified field as the basis for ordering comparisons.

  ## Examples

      defmodule Person do
        defstruct [:name, :age]
      end

      require Monex.Macros
      Monex.Macros.ord_for(Person, :age)

      iex> Ord.lt?(%Person{age: 25}, %Person{age: 30})
      true

      iex> Ord.gt?(%Person{age: 35}, %Person{age: 30})
      true
  """
  defmacro ord_for(for_struct, field) do
    quote do
      alias Monex.Ord

      defimpl Monex.Ord, for: unquote(for_struct) do
        def lt?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.lt?(v1, v2)

        def le?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.le?(v1, v2)

        def gt?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.gt?(v1, v2)

        def ge?(%unquote(for_struct){unquote(field) => v1}, %unquote(for_struct){
              unquote(field) => v2
            }),
            do: Ord.ge?(v1, v2)
      end
    end
  end
end
