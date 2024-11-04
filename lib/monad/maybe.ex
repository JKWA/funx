defmodule Monex.Maybe do
  @moduledoc """
  The `Monex.Maybe` module provides an implementation of the `Maybe` monad, representing optional values as either `Just` (a value) or `Nothing` (no value).

  ### Constructors
    - `pure/1`: Wraps a value in the `Just` monad.
    - `just/1`: Alias for `pure/1`.
    - `nothing/0`: Returns a `Nothing` value.

  ### Lifts
    - `lift_predicate/2`: Lifts a value into a `Maybe` based on a predicate.
    - `lift_identity/1`: Converts an `Identity` value to a `Maybe`.
    - `lift_either/1`: Lifts an `Either` value to a `Maybe`.


  ### Refinements
    - `just?/1`: Checks if a `Maybe` is a `Just` value.
    - `nothing?/1`: Checks if a `Maybe` is a `Nothing` value.

  ### Comparison
    - `get_eq/1`: Returns a custom equality function for `Maybe` values.
    - `get_ord/1`: Returns a custom ordering function for `Maybe` values.

  ### Matching & Filtering
    - `filter/2`: Filters the value inside a `Maybe` using a predicate.
    - `get_or_else/2`: Retrieves the value from a `Maybe`, returning a default if `Nothing`.

  ### Sequencing
    - `sequence/1`: Sequences a list of `Maybe` values.
    - `traverse/2`: Applies a function to a list and sequences the result.

  ### Elixir Interops
    - `from_nil/1`: Converts `nil` to a `Maybe`.
    - `to_nil/1`: Converts a `Maybe` to `nil` or its value.
    - `from_try/1`: Wraps a value in a `Maybe`, catching exceptions.
    - `to_try!/2`: Converts a `Maybe` to its value or raises an exception if `Nothing`.
    - `from_result/1`: Converts a result (`{:ok, _}` or `{:error, _}`) to a `Maybe`.
    - `to_result/1`: Converts a `Maybe` to a result (`{:ok, value}` or `{:error, :nothing}`).
  """
  import Monex.Monad, only: [bind: 2]
  import Monex.Foldable, only: [fold_r: 3]
  alias Monex.Maybe.{Just, Nothing}
  alias Monex.Either.{Left, Right}
  alias Monex.Identity

  @type t(value) :: Just.t(value) | Nothing.t()

  @doc """
  Wraps a value in the `Just` monad.

  ## Examples

      iex> Monex.Maybe.pure(5)
      %Monex.Maybe.Just{value: 5}
  """

  def pure(value), do: Just.pure(value)

  @doc """
  Alias for `pure/1`.
  """
  def just(value), do: Just.pure(value)

  @doc """
  Returns a `Nothing` value.

  ## Examples

      iex> Monex.Maybe.nothing()
      %Monex.Maybe.Nothing{}
  """
  def nothing, do: Nothing.pure()

  @doc """
  Filters the value inside a `Maybe` using the given `predicate`. If the predicate returns `true`,
  the value is kept, otherwise `Nothing` is returned.

  ## Examples

      iex> Monex.Maybe.filter(Monex.Maybe.just(5), fn x -> x > 3 end)
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.filter(Monex.Maybe.just(2), fn x -> x > 3 end)
      %Monex.Maybe.Nothing{}
  """
  def filter(maybe, predicate) do
    bind(maybe, fn value ->
      if predicate.(value) do
        pure(value)
      else
        nothing()
      end
    end)
  end

  @doc """
  Returns `true` if the `Maybe` is a `Just` value.

  ## Examples

      iex> Monex.Maybe.just?(Monex.Maybe.just(5))
      true

      iex> Monex.Maybe.just?(Monex.Maybe.nothing())
      false
  """
  def just?(%Just{}), do: true
  def just?(_), do: false

  @doc """
  Returns `true` if the `Maybe` is a `Nothing` value.

  ## Examples

      iex> Monex.Maybe.nothing?(Monex.Maybe.nothing())
      true

      iex> Monex.Maybe.nothing?(Monex.Maybe.just(5))
      false
  """
  def nothing?(%Nothing{}), do: true
  def nothing?(_), do: false

  @doc """
  Retrieves the value from a `Maybe`, returning the `default` value if `Nothing`.

  ## Examples

      iex> Monex.Maybe.get_or_else(Monex.Maybe.just(5), 0)
      5

      iex> Monex.Maybe.get_or_else(Monex.Maybe.nothing(), 0)
      0
  """
  def get_or_else(maybe, default) do
    fold_r(maybe, fn value -> value end, fn -> default end)
  end

  def get_eq(custom_eq) do
    %{
      eq?: fn
        %Just{value: v1}, %Just{value: v2} -> custom_eq.eq?.(v1, v2)
        %Nothing{}, %Nothing{} -> true
        _, _ -> false
      end
    }
  end

  @doc """
  Creates a custom ordering function for `Maybe` values using the provided `custom_ord`.

  ## Examples

      iex> ord = Monex.Maybe.get_ord(%{lt?: fn x, y -> x < y end})
      iex> ord.lt?.(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true
  """
  def get_ord(custom_ord) do
    %{
      lt?: fn
        %Nothing{}, %Just{} -> true
        %Just{}, %Nothing{} -> false
        %Just{value: v1}, %Just{value: v2} -> custom_ord.lt?.(v1, v2)
        %Nothing{}, %Nothing{} -> false
      end,
      le?: fn a, b -> not get_ord(custom_ord).gt?.(a, b) end,
      gt?: fn a, b -> get_ord(custom_ord).lt?.(b, a) end,
      ge?: fn a, b -> not get_ord(custom_ord).lt?.(a, b) end
    }
  end

  @doc """
  Sequences a list of `Maybe` values into a `Maybe` of a list.

  ## Examples

      iex> Monex.Maybe.sequence([Monex.Maybe.just(1), Monex.Maybe.just(2)])
      %Monex.Maybe.Just{value: [1, 2]}

      iex> Monex.Maybe.sequence([Monex.Maybe.just(1), Monex.Maybe.nothing()])
      %Monex.Maybe.Nothing{}
  """
  def sequence([]), do: pure([])

  def sequence([head | tail]) do
    bind(head, fn value ->
      bind(sequence(tail), fn rest ->
        pure([value | rest])
      end)
    end)
  end

  @doc """
  Applies a function to each element of a list and sequences the result.

  ## Examples

      iex> Monex.Maybe.traverse(fn x -> Monex.Maybe.just(x * 2) end, [1, 2])
      %Monex.Maybe.Just{value: [2, 4]}
  """
  def traverse(func, list) do
    list
    |> Enum.map(func)
    |> sequence()
  end

  @doc """
  Converts an `Identity` value into a `Maybe`. If `Identity` has a value, it is converted to `Just`;
  otherwise, it is converted to `Nothing`.

  ## Examples

      iex> Monex.Maybe.lift_identity(Monex.Identity.pure(5))
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.lift_identity(Monex.Identity.pure(nil))
      %Monex.Maybe.Nothing{}
  """
  def lift_identity(identity) do
    case identity do
      %Identity{value: nil} -> nothing()
      %Identity{value: value} -> just(value)
    end
  end

  @doc """
  Converts an `Either` value into a `Maybe`. `Right` is converted to `Just`, `Left` is converted to `Nothing`.

  ## Examples

      iex> Monex.Maybe.lift_either(Monex.Either.right(5))
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.lift_either(Monex.Either.left("Error"))
      %Monex.Maybe.Nothing{}
  """
  def lift_either(either) do
    case either do
      %Right{value: value} -> just(value)
      %Left{} -> nothing()
    end
  end

  @doc """
  Lifts a value into a `Maybe` based on the result of a predicate.

  ## Examples

      iex> Monex.Maybe.lift_predicate(5, fn x -> x > 3 end)
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.lift_predicate(2, fn x -> x > 3 end)
      %Monex.Maybe.Nothing{}
  """
  def lift_predicate(value, predicate) do
    Monex.Foldable.fold_r(
      fn -> predicate.(value) end,
      fn -> just(value) end,
      fn -> nothing() end
    )
  end

  @doc """
  Converts `nil` to `Nothing`, and any other value to `Just`.

  ## Examples

      iex> Monex.Maybe.from_nil(nil)
      %Monex.Maybe.Nothing{}

      iex> Monex.Maybe.from_nil(5)
      %Monex.Maybe.Just{value: 5}
  """
  @spec from_nil(nil | value) :: t(value) when value: term()
  def from_nil(nil), do: nothing()
  def from_nil(value), do: just(value)

  @doc """
  Converts a `Maybe` to `nil` or its wrapped value.

  ## Examples

      iex> Monex.Maybe.to_nil(Monex.Maybe.just(5))
      5

      iex> Monex.Maybe.to_nil(Monex.Maybe.nothing())
      nil
  """
  @spec to_nil(t(value)) :: nil | value when value: term()
  def to_nil(maybe) do
    fold_r(maybe, fn value -> value end, fn -> nil end)
  end

  @doc """
  Wraps a value in a `Maybe`, catching any exceptions. If an exception occurs, `Nothing` is returned.

  ## Examples

      iex> Monex.Maybe.from_try(fn -> 5 end)
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.from_try(fn -> raise "error" end)
      %Monex.Maybe.Nothing{}
  """
  @spec from_try((-> right)) :: t(right) when right: term()
  # credo:disable-for-next-line
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
  Converts a `Maybe` to its wrapped value, raising an exception if it is `Nothing`.

  ## Examples

      iex> Monex.Maybe.to_try!(Monex.Maybe.just(5))
      5

      iex> Monex.Maybe.to_try!(Monex.Maybe.nothing(), "No value found")
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
  Converts a result (`{:ok, _}` or `{:error, _}`) to a `Maybe`.

  ## Examples

      iex> Monex.Maybe.from_result({:ok, 5})
      %Monex.Maybe.Just{value: 5}

      iex> Monex.Maybe.from_result({:error, :something})
      %Monex.Maybe.Nothing{}
  """
  @spec from_result({:ok, right} | {:error, term()}) :: t(right) when right: term()
  def from_result({:ok, value}), do: just(value)
  def from_result({:error, _reason}), do: nothing()

  @doc """
  Converts a `Maybe` to a result (`{:ok, value}` or `{:error, :nothing}`).

  ## Examples

      iex> Monex.Maybe.to_result(Monex.Maybe.just(5))
      {:ok, 5}

      iex> Monex.Maybe.to_result(Monex.Maybe.nothing())
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
