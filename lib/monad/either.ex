defmodule Funx.Either do
  @moduledoc """
  The `Funx.Either` module provides an implementation of the `Either` monad, which represents values that can either be `Right` (success) or `Left` (error).

  ### Constructors
    - `right/1`: Wraps a value in the `Right` monad.
    - `left/1`: Wraps a value in the `Left` monad.
    - `pure/1`: Alias for `right/1`.

  ### Refinements
    - `right?/1`: Checks if an `Either` value is `Right`.
    - `left?/1`: Checks if an `Either` value is `Left`.

  ### Matching & Filtering
    - `filter_or_else/3`: Filters the value inside a `Right` and returns a `Left` on failure.
    - `get_or_else/2`: Retrieves the value from a `Right`, returning a default if `Left`.

  ### Comparison
    - `lift_eq/1`: Returns a custom equality function for `Either` values.
    - `lift_ord/1`: Returns a custom ordering function for `Either` values.

  ### Sequencing
    - `sequence/1`: Sequences a list of `Either` values.
    - `traverse/2`: Applies a function to a list and sequences the result.
    - `sequence_a/1`: Sequences a list of `Either` values, collecting errors from `Left` values.

  ### Validation
    - `validate/2`: Validates a value using a list of validators, collecting errors from `Left` values.

  ### Lifts
    - `lift_maybe/2`: Lifts a `Maybe` value to an `Either` monad.
    - `lift_predicate/3`: Lifts a value into an `Either` based on a predicate.

  ### Elixir Interops
    - `from_result/1`: Converts a result (`{:ok, _}` or `{:error, _}`) to an `Either`.
    - `to_result/1`: Converts an `Either` to a result (`{:ok, value}` or `{:error, reason}`).
    - `from_try/1`: Wraps a value in an `Either`, catching exceptions.
    - `to_try!/1`: Converts an `Either` to its value or raises an exception if `Left`.
  """

  import Funx.Monad, only: [map: 2]

  import Funx.Foldable, only: [fold_r: 3]
  alias Funx.Either.{Left, Right}
  alias Funx.Eq
  alias Funx.Maybe
  alias Funx.Ord

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` monad.

  ## Examples

      iex> Funx.Either.right(5)
      %Funx.Either.Right{right: 5}
  """
  @spec right(any()) :: Right.t(any())
  def right(value), do: Right.pure(value)

  @doc """
  Alias for `right/1`.
  """
  @spec pure(any()) :: Right.t(any())
  def pure(value), do: Right.pure(value)

  @doc """
  Wraps a value in the `Left` monad.

  ## Examples

      iex> Funx.Either.left("error")
      %Funx.Either.Left{left: "error"}
  """
  @spec left(any()) :: Left.t(any())
  def left(value), do: Left.pure(value)

  @doc """
  Returns `true` if the `Either` is a `Left` value.

  ## Examples

      iex> Funx.Either.left?(Funx.Either.left("error"))
      true

      iex> Funx.Either.left?(Funx.Either.right(5))
      false
  """
  @spec left?(t(any(), any())) :: boolean()
  def left?(%Left{}), do: true
  def left?(_), do: false

  @doc """
  Returns `true` if the `Either` is a `Right` value.

  ## Examples

      iex> Funx.Either.right?(Funx.Either.right(5))
      true

      iex> Funx.Either.right?(Funx.Either.left("error"))
      false
  """
  @spec right?(t(any(), any())) :: boolean()
  def right?(%Right{}), do: true
  def right?(_), do: false

  @doc """
  Filters the value inside a `Right` using the given `predicate`. If the predicate returns `false`,
  a `Left` is returned using the `left_func`.

  ## Examples

      iex> Funx.Either.filter_or_else(Funx.Either.right(5), fn x -> x > 3 end, fn -> "error" end)
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.filter_or_else(Funx.Either.right(2), fn x -> x > 3 end, fn -> "error" end)
      %Funx.Either.Left{left: "error"}
  """
  @spec filter_or_else(t(any(), any()), (any() -> boolean()), (-> any())) :: t(any(), any())
  def filter_or_else(either, predicate, left_func) do
    fold_r(
      either,
      fn value ->
        if predicate.(value) do
          either
        else
          Left.pure(left_func.())
        end
      end,
      fn _left_value -> either end
    )
  end

  @doc """
  Retrieves the value from a `Right`, returning the `default` value if `Left`.

  ## Examples

      iex> Funx.Either.get_or_else(Funx.Either.right(5), 0)
      5

      iex> Funx.Either.get_or_else(Funx.Either.left("error"), 0)
      0
  """
  @spec get_or_else(t(any(), any()), any()) :: any()
  def get_or_else(either, default) do
    fold_r(
      either,
      fn value -> value end,
      fn _left_value -> default end
    )
  end

  @doc """
  Returns the current `Right` value or invokes the `fallback_fun` if `Left`.

  Useful for recovering from a failure by providing an alternate computation.

  ## Examples

      iex> Funx.Either.or_else(Funx.Either.left("error"), fn -> Funx.Either.right(42) end)
      %Funx.Either.Right{right: 42}

      iex> Funx.Either.or_else(Funx.Either.right(10), fn -> Funx.Either.right(42) end)
      %Funx.Either.Right{right: 10}
  """
  @spec or_else(t(error, value), (-> t(error, value))) :: t(error, value)
        when error: term(), value: term()
  def or_else(%Left{}, fallback_fun) when is_function(fallback_fun, 0), do: fallback_fun.()
  def or_else(%Right{} = right, _fallback_fun), do: right

  @doc """
  Lifts an equality function to compare `Either` values:
    - `Right` vs `Right`: Uses the custom equality function.
    - `Left` vs `Left`: Uses the custom equality function.
    - `Left` vs `Right` or vice versa: Always `false`.

  ## Examples

      iex> eq = Funx.Either.lift_eq(%{
      ...>   eq?: fn x, y -> x == y end,
      ...>   not_eq?: fn x, y -> x != y end
      ...> })
      iex> eq.eq?.(Funx.Either.right(5), Funx.Either.right(5))
      true
      iex> eq.eq?.(Funx.Either.right(5), Funx.Either.right(10))
      false
      iex> eq.eq?.(Funx.Either.left(:a), Funx.Either.left(:a))
      true
      iex> eq.eq?.(Funx.Either.left(:a), Funx.Either.left(:b))
      false
      iex> eq.eq?.(Funx.Either.right(5), Funx.Either.left(:a))
      false
  """
  @spec lift_eq(Eq.Utils.eq_t()) :: Eq.Utils.eq_map()
  def lift_eq(custom_eq) do
    custom_eq = Eq.Utils.to_eq_map(custom_eq)

    %{
      eq?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_eq.eq?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_eq.eq?.(v1, v2)
        %Left{}, %Right{} -> false
        %Right{}, %Left{} -> false
      end,
      not_eq?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_eq.not_eq?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_eq.not_eq?.(v1, v2)
        %Left{}, %Right{} -> true
        %Right{}, %Left{} -> true
      end
    }
  end

  @doc """
  Creates a custom ordering function for `Either` values using the provided `custom_ord`.

  The `custom_ord` must be a map with `:lt?`, `:le?`, `:gt?`, and `:ge?` functions. These are used to compare the internal `left` or `right` values.

  ## Examples

      iex> ord = Funx.Either.lift_ord(%{
      ...>   lt?: fn x, y -> x < y end,
      ...>   le?: fn x, y -> x <= y end,
      ...>   gt?: fn x, y -> x > y end,
      ...>   ge?: fn x, y -> x >= y end
      ...> })
      iex> ord.lt?.(Funx.Either.right(3), Funx.Either.right(5))
      true
      iex> ord.lt?.(Funx.Either.left(3), Funx.Either.right(5))
      true
      iex> ord.lt?.(Funx.Either.right(3), Funx.Either.left(5))
      false
      iex> ord.lt?.(Funx.Either.left(3), Funx.Either.left(5))
      true
  """
  @spec lift_ord(Ord.Utils.ord_t()) :: Ord.Utils.ord_map()
  def lift_ord(custom_ord) do
    custom_ord = Ord.Utils.to_ord_map(custom_ord)

    %{
      lt?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_ord.lt?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_ord.lt?.(v1, v2)
        %Left{}, %Right{} -> true
        %Right{}, %Left{} -> false
      end,
      le?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_ord.le?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_ord.le?.(v1, v2)
        %Left{}, %Right{} -> true
        %Right{}, %Left{} -> false
      end,
      gt?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_ord.gt?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_ord.gt?.(v1, v2)
        %Right{}, %Left{} -> true
        %Left{}, %Right{} -> false
      end,
      ge?: fn
        %Right{right: v1}, %Right{right: v2} -> custom_ord.ge?.(v1, v2)
        %Left{left: v1}, %Left{left: v2} -> custom_ord.ge?.(v1, v2)
        %Right{}, %Left{} -> true
        %Left{}, %Right{} -> false
      end
    }
  end

  @doc """
  Removes `Left` values from a list of `Either` and returns a list of unwrapped `Right` values.

  Useful for discarding failed computations while keeping successful results.

  ## Examples

      iex> Funx.Either.concat([Funx.Either.right(1), Funx.Either.left(:error), Funx.Either.right(2)])
      [1, 2]

      iex> Funx.Either.concat([Funx.Either.left(:a), Funx.Either.left(:b)])
      []

      iex> Funx.Either.concat([Funx.Either.right("a"), Funx.Either.right("b"), Funx.Either.right("c")])
      ["a", "b", "c"]
  """
  @spec concat([t(error, value)]) :: [value]
        when error: term(), value: any()
  def concat(list) when is_list(list) do
    list
    |> Enum.reduce([], fn
      %Right{right: value}, acc -> [value | acc]
      %Left{}, acc -> acc
    end)
    |> :lists.reverse()
  end

  @doc """
  Applies the given function to each element in the list and collects the `Right` results, discarding any `Left`.

  This is useful when mapping a function that may fail and you only want the successful results.

  ## Examples

      iex> Funx.Either.concat_map([1, 2, 3], fn x -> if rem(x, 2) == 1, do: Funx.Either.right(x), else: Funx.Either.left(:even) end)
      [1, 3]

      iex> Funx.Either.concat_map([2, 4], fn x -> if x > 3, do: Funx.Either.right(x), else: Funx.Either.left(:too_small) end)
      [4]

      iex> Funx.Either.concat_map([], fn _ -> Funx.Either.left(:none) end)
      []
  """
  @spec concat_map([input], (input -> t(error, output))) :: [output]
        when input: any(), output: any(), error: any()
  def concat_map(list, func) when is_list(list) and is_function(func, 1) do
    Enum.reduce(list, [], fn item, acc ->
      case func.(item) do
        %Right{right: value} -> [value | acc]
        %Left{} -> acc
      end
    end)
    |> :lists.reverse()
  end

  @doc """
  Sequences a list of `Either` values into an `Either` of a list.

  ## Examples

      iex> Funx.Either.sequence([Funx.Either.right(1), Funx.Either.right(2)])
      %Funx.Either.Right{right: [1, 2]}

      iex> Funx.Either.sequence([Funx.Either.right(1), Funx.Either.left("error")])
      %Funx.Either.Left{left: "error"}
  """
  @spec sequence([t(error, value)]) :: t(error, [value]) when error: term(), value: term()
  def sequence(list) when is_list(list), do: traverse(list, fn x -> x end)

  @doc """
  Traverses a list, applying the given function to each element and collecting the results in a single `Right`, or short-circuiting with the first `Left`.

  This is useful for validating or transforming a list of values where each step may fail.

  ## Examples

      iex> Funx.Either.traverse([1, 2, 3], &Funx.Either.right/1)
      %Funx.Either.Right{right: [1, 2, 3]}

      iex> Funx.Either.traverse([1, -2, 3], fn x -> if x > 0, do: Funx.Either.right(x), else: Funx.Either.left("error") end)
      %Funx.Either.Left{left: "error"}
  """

  @spec traverse([a], (a -> t(error, b))) :: t(error, [b])
        when a: term(), b: term(), error: term()

  def traverse([], _func), do: pure([])

  def traverse(list, func) when is_list(list) and is_function(func, 1) do
    list
    |> Enum.reduce_while(pure([]), fn item, %Right{right: acc} ->
      case func.(item) do
        %Right{right: value} -> {:cont, pure([value | acc])}
        %Left{} = left -> {:halt, left}
      end
    end)
    |> map(&:lists.reverse/1)
  end

  @doc """
  Sequences a list of `Either` values, collecting all errors from `Left` values, rather than short-circuiting.

  ## Examples

      iex> Funx.Either.sequence_a([Funx.Either.right(1), Funx.Either.left("error"), Funx.Either.left("another error")])
      %Funx.Either.Left{left: ["error", "another error"]}
  """
  @spec sequence_a([t(error, value)]) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a([]), do: right([])

  def sequence_a([head | tail]) do
    case head do
      %Right{right: value} ->
        sequence_a(tail)
        |> case do
          %Right{right: values} -> right([value | values])
          %Left{left: errors} -> left(errors)
        end

      %Left{left: error} ->
        sequence_a(tail)
        |> case do
          %Right{right: _values} -> left([error])
          %Left{left: errors} -> left([error | errors])
        end
    end
  end

  @doc """
  Validates a value using a list of validator functions. Each validator returns an `Either`: a `Right` if the check passes, or a `Left` with an error.

  If any validator returns a `Left`, all errors are collected and returned in a `Left`. If all validators succeed, the original value is returned in a `Right`.

  ## Examples

      iex> validate_positive = fn x -> Funx.Either.lift_predicate(x, &(&1 > 0), fn -> "Value must be positive" end) end
      iex> validate_even = fn x -> Funx.Either.lift_predicate(x, &rem(&1, 2) == 0, fn -> "Value must be even" end) end
      iex> Funx.Either.validate(4, [validate_positive, validate_even])
      %Funx.Either.Right{right: 4}
      iex> Funx.Either.validate(3, [validate_positive, validate_even])
      %Funx.Either.Left{left: ["Value must be even"]}
      iex> Funx.Either.validate(-3, [validate_positive, validate_even])
      %Funx.Either.Left{left: ["Value must be positive", "Value must be even"]}
  """
  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()
  def validate(value, validators) when is_list(validators) do
    results = Enum.map(validators, fn validator -> validator.(value) end)

    case sequence_a(results) do
      %Right{} -> right(value)
      %Left{left: errors} -> left(errors)
    end
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{} -> right(value)
      %Left{left: error} -> left([error])
    end
  end

  @doc """
  Converts a `Maybe` value to an `Either`. If the `Maybe` is `Nothing`, a `Left` is returned using `on_none`.

  ## Examples

      iex> Funx.Either.lift_maybe(Funx.Maybe.just(5), fn -> "error" end)
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.lift_maybe(Funx.Maybe.nothing(), fn -> "error" end)
      %Funx.Either.Left{left: "error"}
  """
  @spec lift_maybe(Maybe.t(any()), (-> any())) :: t(any(), any())
  def lift_maybe(maybe, on_none) do
    maybe
    |> fold_r(
      fn value -> Right.pure(value) end,
      fn -> Left.pure(on_none.()) end
    )
  end

  @doc """
  Lifts a value into an `Either` based on the result of a predicate.

  ## Examples

      iex> Funx.Either.lift_predicate(5, fn x -> x > 3 end, fn -> "too small" end)
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.lift_predicate(2, fn x -> x > 3 end, fn -> "too small" end)
      %Funx.Either.Left{left: "too small"}
  """
  @spec lift_predicate(any(), (any() -> boolean()), (-> any())) :: t(any(), any())
  def lift_predicate(value, predicate, on_false) do
    fold_r(
      fn -> predicate.(value) end,
      fn -> Right.pure(value) end,
      fn -> Left.pure(on_false.()) end
    )
  end

  @doc """
  Converts a result (`{:ok, _}` or `{:error, _}`) to an `Either`.

  ## Examples

      iex> Funx.Either.from_result({:ok, 5})
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.from_result({:error, "error"})
      %Funx.Either.Left{left: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}) :: t(left, right)
        when left: term(), right: term()
  def from_result({:ok, value}), do: Right.pure(value)
  def from_result({:error, reason}), do: Left.pure(reason)

  @doc """
  Converts an `Either` to a result (`{:ok, value}` or `{:error, reason}`).

  ## Examples

      iex> Funx.Either.to_result(Funx.Either.right(5))
      {:ok, 5}

      iex> Funx.Either.to_result(Funx.Either.left("error"))
      {:error, "error"}
  """
  @spec to_result(t(left, right)) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(either) do
    case either do
      %Right{right: value} -> {:ok, value}
      %Left{left: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a value in an `Either`, catching any exceptions. If an exception occurs, a `Left` is returned with the exception.

  ## Examples

      iex> Funx.Either.from_try(fn -> 5 end)
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.from_try(fn -> raise "error" end)
      %Funx.Either.Left{left: %RuntimeError{message: "error"}}
  """
  @spec from_try((-> right)) :: t(Exception.t(), right) when right: term()
  def from_try(func) do
    try do
      result = func.()
      Right.pure(result)
    rescue
      exception ->
        Left.pure(exception)
    end
  end

  @doc """
  Converts an `Either` to its wrapped value, raising an exception if it is `Left`.

  ## Examples

      iex> Funx.Either.to_try!(Funx.Either.right(5))
      5

      iex> Funx.Either.to_try!(Funx.Either.left("error"))
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(either) do
    case either do
      %Right{right: value} ->
        value

      %Left{left: reason} ->
        raise reason
    end
  end
end
