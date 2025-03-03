defmodule Funx.Maybe do
  @moduledoc """
  The `Funx.Maybe` module provides an implementation of the `Maybe` monad, giving you a convenient way to represent optional values in Elixir. By encapsulating values in `Just` or `Nothing`, this module lets you handle the presence or absence of data in a consistent, composable manner.

  ## Features

  - **Constructors**: Easily create `Maybe` values.
  - **Lifting Functions**: Convert standard or custom types into `Maybe` values.
  - **Checks & Filters**: Determine whether a `Maybe` is `Just` or `Nothing` and filter data accordingly.
  - **List Operations**: Efficiently transform and collect `Maybe` values in lists.
  - **Interop**: Translate between `Maybe` and native Elixir constructs like `nil`, tuples, or exceptions.

  ### Usage Overview

  1. **Construct**: Use `just/1` or `nothing/0` to build `Maybe` values.
  2. **Check**: Use `just?/1` or `nothing?/1` to see if you have a `Just` or `Nothing`.
  3. **Filter & Transform**: Apply `filter/2`, `map`, or `bind` for transformations.
  4. **Extract**: Use `get_or_else/2`, `to_nil/1`, or `to_try!/2` to retrieve the raw data.

  ### Constructors

  - `pure/1`: Wraps a value in `Just`.
  - `just/1`: Alias for `pure/1`.
  - `nothing/0`: Returns a `Nothing` value.

  ### Lifting Functions

  - `lift_predicate/2`: Converts a value to `Just` if it meets a predicate, otherwise `Nothing`.
  - `lift_identity/1`: Converts an `Identity` to a `Maybe`.
  - `lift_either/1`: Converts an `Either` to a `Maybe`.
  - `lift_eq/1`: Lifts an equality function for `Maybe` values.
  - `lift_ord/1`: Lifts an ordering function for `Maybe` values.

  ### Checks & Filters

  - `just?/1`: Checks if a `Maybe` is `Just`.
  - `nothing?/1`: Checks if a `Maybe` is `Nothing`.
  - `filter/2`: Keeps the value if it matches a predicate, otherwise returns `Nothing`.
  - `guard/2`: Retains the `Maybe` if the boolean is `true`, otherwise returns `Nothing`.
  - `get_or_else/2`: Returns the value or a default.
  - `or_else/2`: Returns the `Just` value or calls a fallback function if `Nothing`.

  ### Working with Lists

  - `concat/1`: Extracts present values (`Just`) from a list of `Maybe`.
  - `concat_map/2`: Maps and extracts `Just` values in one pass.
  - `sequence/1`: Converts a list of `Maybe` into a single `Maybe` containing a list.
  - `traverse/2`: Applies a function to each element and sequences the results, returning one `Maybe`.

  ### Elixir Interop

  - `from_nil/1`: Converts `nil` to `Nothing`, otherwise `Just`.
  - `to_nil/1`: Returns the underlying value or `nil`.
  - `from_try/1`: Executes a function and wraps its result in `Maybe` or returns `Nothing` on exception.
  - `to_try!/2`: Extracts the value or raises an error if `Nothing`.
  - `from_result/1`: Converts `{:ok, _}` or `{:error, _}` tuples to `Maybe`.
  - `to_result/1`: Turns a `Maybe` into `{:ok, value}` or `{:error, :nothing}`.
  """

  import Funx.Monad, only: [bind: 2, map: 2]
  import Funx.Foldable, only: [fold_l: 3]
  alias Funx.Maybe.{Just, Nothing}
  alias Funx.Either.{Left, Right}
  alias Funx.Eq
  alias Funx.Identity
  alias Funx.Ord

  @type t(value) :: Just.t(value) | Nothing.t()

  @doc """
  Wraps a value in `Just`.

  ## Examples

      iex> Funx.Maybe.pure(5)
      %Funx.Maybe.Just{value: 5}
  """
  @spec pure(any()) :: Just.t(any())
  def pure(value), do: Just.pure(value)

  @doc """
  Alias for `pure/1`.
  """
  @spec just(any()) :: Just.t(any())
  def just(value), do: Just.pure(value)

  @doc """
  Returns a `Nothing` value.

  ## Examples

      iex> Funx.Maybe.nothing()
      %Funx.Maybe.Nothing{}
  """
  @spec nothing() :: Nothing.t()
  def nothing, do: Nothing.pure()

  @doc """
  Returns `true` if the `Maybe` is `Just`, otherwise `false`.

  ## Examples

      iex> Funx.Maybe.just?(Funx.Maybe.just(5))
      true

      iex> Funx.Maybe.just?(Funx.Maybe.nothing())
      false
  """
  @spec just?(t(any())) :: boolean()
  def just?(%Just{}), do: true
  def just?(_), do: false

  @doc """
  Returns `true` if the `Maybe` is `Nothing`, otherwise `false`.

  ## Examples

      iex> Funx.Maybe.nothing?(Funx.Maybe.nothing())
      true

      iex> Funx.Maybe.nothing?(Funx.Maybe.just(5))
      false
  """
  @spec nothing?(t(any())) :: boolean()
  def nothing?(%Nothing{}), do: true
  def nothing?(_), do: false

  @doc """
  Retrieves the value from a `Maybe`, returning `default` if `Nothing`.

  ## Examples

      iex> Funx.Maybe.get_or_else(Funx.Maybe.just(5), 0)
      5

      iex> Funx.Maybe.get_or_else(Funx.Maybe.nothing(), 0)
      0
  """
  @spec get_or_else(t(value), value) :: value when value: var
  def get_or_else(maybe, default) do
    fold_l(maybe, fn value -> value end, fn -> default end)
  end

  @doc """
  Returns the current `Just` value or invokes the `fallback_fun` if `Nothing`.

  ## Examples

      iex> Funx.Maybe.or_else(Funx.Maybe.nothing(), fn -> Funx.Maybe.just(42) end)
      %Funx.Maybe.Just{value: 42}

      iex> Funx.Maybe.or_else(Funx.Maybe.just(10), fn -> Funx.Maybe.just(42) end)
      %Funx.Maybe.Just{value: 10}
  """
  @spec or_else(t(value), (-> t(value))) :: t(value) when value: var
  def or_else(%Nothing{}, fallback_fun) when is_function(fallback_fun, 0), do: fallback_fun.()
  def or_else(%Just{} = just, _fallback_fun), do: just

  @doc """
  Lifts an equality function to compare `Maybe` values:
    - `Just` vs `Just`: Uses the custom equality function.
    - `Nothing` vs `Nothing`: Always `true`.
    - `Just` vs `Nothing` or vice versa: Always `false`.

  ## Examples

      iex> eq = Funx.Maybe.lift_eq(%{eq?: fn x, y -> x == y end})
      iex> eq.eq?.(Funx.Maybe.just(5), Funx.Maybe.just(5))
      true
      iex> eq.eq?.(Funx.Maybe.just(5), Funx.Maybe.just(10))
      false
  """
  @spec lift_eq(Eq.Utils.eq_map()) :: Eq.Utils.eq_map()
  def lift_eq(custom_eq) do
    eq_fn = fn
      %Just{value: v1}, %Just{value: v2} -> custom_eq.eq?.(v1, v2)
      %Nothing{}, %Nothing{} -> true
      %Nothing{}, %Just{} -> false
      %Just{}, %Nothing{} -> false
    end

    %{
      eq?: eq_fn,
      not_eq?: fn a, b -> not eq_fn.(a, b) end
    }
  end

  @doc """
  Adapts an ordering function to compare `Maybe` values:
    - `Nothing` is considered less than any `Just`.
    - Two `Just` values are compared by the provided function.

  ## Examples

      iex> ord = Funx.Maybe.lift_ord(%{lt?: fn x, y -> x < y end})
      iex> ord.lt?.(Funx.Maybe.just(3), Funx.Maybe.just(5))
      true
  """
  @spec lift_ord(Ord.Utils.ord_map()) :: Ord.Utils.ord_map()
  def lift_ord(custom_ord) do
    %{
      lt?: fn
        %Nothing{}, %Just{} -> true
        %Just{}, %Nothing{} -> false
        %Just{value: v1}, %Just{value: v2} -> custom_ord.lt?.(v1, v2)
        %Nothing{}, %Nothing{} -> false
      end,
      le?: fn a, b -> not lift_ord(custom_ord).gt?.(a, b) end,
      gt?: fn a, b -> lift_ord(custom_ord).lt?.(b, a) end,
      ge?: fn a, b -> not lift_ord(custom_ord).lt?.(a, b) end
    }
  end

  @doc """
  Removes `Nothing` values from a list of `Maybe` and returns a list of unwrapped `Just` values.

  ## Examples

      iex> Funx.Maybe.concat([Funx.Maybe.pure(1), Funx.Maybe.nothing(), Funx.Maybe.pure(2)])
      [1, 2]

      iex> Funx.Maybe.concat([Funx.Maybe.nothing(), Funx.Maybe.nothing()])
      []

      iex> Funx.Maybe.concat([Funx.Maybe.pure("a"), Funx.Maybe.pure("b"), Funx.Maybe.pure("c")])
      ["a", "b", "c"]
  """
  @spec concat([t(output)]) :: [output] when output: any()
  def concat(list) when is_list(list) do
    list
    |> Enum.reduce([], fn
      %Just{value: value}, acc -> [value | acc]
      %Nothing{}, acc -> acc
    end)
    |> :lists.reverse()
  end

  @doc """
  Maps a function over a list, collecting unwrapped `Just` values and ignoring `Nothing` in a single pass.

  ## Examples

      iex> Funx.Maybe.concat_map([1, 2, 3, 4], fn x ->
      ...>   if rem(x, 2) == 0, do: Funx.Maybe.pure(x), else: Funx.Maybe.nothing()
      ...> end)
      [2, 4]

      iex> Funx.Maybe.concat_map([1, nil, 3], fn
      ...>   nil -> Funx.Maybe.nothing()
      ...>   x -> Funx.Maybe.pure(x * 2)
      ...> end)
      [2, 6]

      iex> Funx.Maybe.concat_map([1, 2, 3], fn x -> Funx.Maybe.pure(x + 1) end)
      [2, 3, 4]

      iex> Funx.Maybe.concat_map([], fn x -> Funx.Maybe.pure(x) end)
      []
  """
  @spec concat_map([input], (input -> t(output))) :: [output] when input: any(), output: any()
  def concat_map(list, func) when is_list(list) and is_function(func, 1) do
    Enum.reduce(list, [], fn item, acc ->
      case func.(item) do
        %Just{value: value} -> [value | acc]
        %Nothing{} -> acc
      end
    end)
    |> :lists.reverse()
  end

  @doc """
  Converts a list of `Maybe` values into a `Maybe` containing a list. If any element is `Nothing`, the entire result is `Nothing`.

  ## Examples

      iex> Funx.Maybe.sequence([Funx.Maybe.just(1), Funx.Maybe.just(2)])
      %Funx.Maybe.Just{value: [1, 2]}

      iex> Funx.Maybe.sequence([Funx.Maybe.just(1), Funx.Maybe.nothing()])
      %Funx.Maybe.Nothing{}
  """
  @spec sequence([t(value)]) :: t([value]) when value: any()
  def sequence([]), do: pure([])

  def sequence([head | tail]) do
    bind(head, fn value ->
      bind(sequence(tail), fn rest ->
        pure([value | rest])
      end)
    end)
  end

  @doc """
  Applies a function to each element of a list, collecting results into a single `Maybe`. If any call returns `Nothing`, the operation halts and returns `Nothing`.

  ## Examples

      iex> Funx.Maybe.traverse([1, 2], fn x -> Funx.Maybe.just(x * 2) end)
      %Funx.Maybe.Just{value: [2, 4]}

      iex> Funx.Maybe.traverse([1, nil, 3], fn
      ...>   nil -> Funx.Maybe.nothing()
      ...>   x -> Funx.Maybe.just(x * 2)
      ...> end)
      %Funx.Maybe.Nothing{}
  """
  @spec traverse([input], (input -> t(output))) :: t([output]) when input: any(), output: any()
  def traverse([], _func), do: pure([])

  def traverse(list, func) when is_list(list) and is_function(func, 1) do
    list
    |> Enum.reduce_while(pure([]), fn item, %Just{value: acc} ->
      case func.(item) do
        %Just{value: value} -> {:cont, pure([value | acc])}
        %Nothing{} -> {:halt, nothing()}
      end
    end)
    |> map(&:lists.reverse/1)
  end

  @doc """
  Converts an `Identity` value into a `Maybe`. If the value is `nil`, returns `Nothing`; otherwise `Just`.

  ## Examples

      iex> Funx.Maybe.lift_identity(Funx.Identity.pure(5))
      %Funx.Maybe.Just{value: 5}

      iex> Funx.Maybe.lift_identity(Funx.Identity.pure(nil))
      %Funx.Maybe.Nothing{}
  """
  def lift_identity(identity) do
    case identity do
      %Identity{value: nil} -> nothing()
      %Identity{value: value} -> just(value)
    end
  end

  @doc """
  Converts an `Either` to a `Maybe`. `Right` becomes `Just`, and `Left` becomes `Nothing`.

  ## Examples

      iex> Funx.Maybe.lift_either(Funx.Either.right(5))
      %Funx.Maybe.Just{value: 5}

      iex> Funx.Maybe.lift_either(Funx.Either.left("Error"))
      %Funx.Maybe.Nothing{}
  """
  def lift_either(either) do
    case either do
      %Right{right: value} -> just(value)
      %Left{} -> nothing()
    end
  end

  @doc """
  Lifts a value into `Maybe` based on a predicate. If `predicate.(value)` is `true`, returns `Just(value)`; otherwise `Nothing`.

  ## Examples

      iex> Funx.Maybe.lift_predicate(5, fn x -> x > 3 end)
      %Funx.Maybe.Just{value: 5}

      iex> Funx.Maybe.lift_predicate(2, fn x -> x > 3 end)
      %Funx.Maybe.Nothing{}
  """
  @spec lift_predicate(term(), (term() -> boolean())) :: t(term())
  def lift_predicate(value, predicate) do
    fold_l(
      fn -> predicate.(value) end,
      fn -> just(value) end,
      fn -> nothing() end
    )
  end

  @spec to_predicate(t(any())) :: boolean()
  def to_predicate(maybe) do
    fold_l(maybe, fn _value -> true end, fn -> false end)
  end

  @doc """
  Converts `nil` to `Nothing`; any other value becomes `Just`.

  ## Examples

      iex> Funx.Maybe.from_nil(nil)
      %Funx.Maybe.Nothing{}

      iex> Funx.Maybe.from_nil(5)
      %Funx.Maybe.Just{value: 5}
  """
  @spec from_nil(nil | value) :: t(value) when value: term()
  def from_nil(nil), do: nothing()
  def from_nil(value), do: just(value)

  @doc """
  Converts a `Maybe` to its wrapped value or `nil`.

  ## Examples

      iex> Funx.Maybe.to_nil(Funx.Maybe.just(5))
      5

      iex> Funx.Maybe.to_nil(Funx.Maybe.nothing())
      nil
  """
  @spec to_nil(t(value)) :: nil | value when value: term()
  def to_nil(maybe) do
    fold_l(maybe, fn value -> value end, fn -> nil end)
  end

  @doc """
  Executes a function within a `Maybe` context, returning `Nothing` if an exception occurs.

  ## Examples

      iex> Funx.Maybe.from_try(fn -> 5 end)
      %Funx.Maybe.Just{value: 5}

      iex> Funx.Maybe.from_try(fn -> raise "error" end)
      %Funx.Maybe.Nothing{}
  """
  @spec from_try((-> right)) :: t(right) when right: term()
  def from_try(func) do
    try do
      result = func.()
      just(result)
    rescue
      _exception ->
        nothing()
    end
  end

  @doc """
  Extracts a value from a `Maybe`, raising an exception if `Nothing`.

  ## Examples

      iex> Funx.Maybe.to_try!(Funx.Maybe.just(5))
      5

      iex> Funx.Maybe.to_try!(Funx.Maybe.nothing(), "No value found")
      ** (RuntimeError) No value found
  """
  @spec to_try!(t(right), String.t()) :: right | no_return when right: term()
  def to_try!(maybe, message \\ "Nothing value encountered") do
    case maybe do
      %Just{value: value} -> value
      %Nothing{} -> raise message
    end
  end

  @doc """
  Converts a result tuple to a `Maybe`. `{:ok, value}` becomes `Just(value)`, while `{:error, _}` becomes `Nothing`.

  ## Examples

      iex> Funx.Maybe.from_result({:ok, 5})
      %Funx.Maybe.Just{value: 5}

      iex> Funx.Maybe.from_result({:error, :something})
      %Funx.Maybe.Nothing{}
  """
  @spec from_result({:ok, right} | {:error, term()}) :: t(right) when right: term()
  def from_result({:ok, value}), do: just(value)
  def from_result({:error, _reason}), do: nothing()

  @doc """
  Converts a `Maybe` to a result tuple. `Just(value)` becomes `{:ok, value}`, while `Nothing` becomes `{:error, :nothing}`.

  ## Examples

      iex> Funx.Maybe.to_result(Funx.Maybe.just(5))
      {:ok, 5}

      iex> Funx.Maybe.to_result(Funx.Maybe.nothing())
      {:error, :nothing}
  """
  @spec to_result(t(right)) :: {:ok, right} | {:error, :nothing} when right: term()
  def to_result(maybe) do
    case maybe do
      %Just{value: value} -> {:ok, value}
      %Nothing{} -> {:error, :nothing}
    end
  end
end
