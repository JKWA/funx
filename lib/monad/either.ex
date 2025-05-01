defmodule Funx.Either do
  @moduledoc """
  The `Funx.Either` module provides an implementation of the `Either` monad, a functional abstraction used to model computations that may fail.

  An `Either` represents one of two possibilities:

    - `Right(value)`: a successful result
    - `Left(error)`: a failure or error

  This pattern is commonly used in place of exceptions to handle errors explicitly and safely in functional pipelines.

  ### Constructors

    - `right/1`: Wraps a value in the `Right` branch.
    - `left/1`: Wraps a value in the `Left` branch.
    - `pure/1`: Alias for `right/1`.

  ### Refinement

    - `right?/1`: Returns `true` if the value is a `Right`.
    - `left?/1`: Returns `true` if the value is a `Left`.

  ### Fallback and Extraction

    - `get_or_else/2`: Returns the value from a `Right`, or a default if `Left`.
    - `or_else/2`: Returns the original `Right`, or invokes a fallback function if `Left`.
    - `map_left/2`: Transforms a `Left` using a function, leaving `Right` values unchanged.

  ### List Operations

    - `concat/1`: Removes all `Left` values and unwraps the `Right` values from a list.
    - `concat_map/2`: Applies a function and collects only `Right` results.
    - `sequence/1`: Converts a list of `Either` values into a single `Either` of list.
    - `traverse/2`: Applies a function to each element in a list and sequences the results.
    - `sequence_a/1`: Like `sequence/1`, but accumulates all errors from `Left` values.
    - `traverse_a/2`: Like `traverse/2`, but accumulates all `Left` values instead of short-circuiting.
    - `wither_a/2`: Like `traverse_a/2`, but filters out `Nothing` results and collects only `Just` values.

  ### Validation

    - `validate/2`: Applies multiple validators to a single input, collecting all errors.

  ### Lifting

    - `lift_predicate/3`: Turns a predicate into an `Either`, returning `Right` on `true` and `Left` on `false`.
    - `lift_maybe/2`: Converts a `Maybe` to an `Either` using a fallback value.
    - `lift_eq/1`: Lifts an equality function into the `Either` context.
    - `lift_ord/1`: Lifts an ordering function into the `Either` context.

  ### Elixir Interoperability

    - `from_result/1`: Converts `{:ok, val}` or `{:error, err}` into an `Either`.
    - `to_result/1`: Converts an `Either` into a result tuple.
    - `from_try/1`: Runs a function and returns `Right` on success or `Left` on exception.
    - `to_try!/1`: Unwraps a `Right`, or raises an error from a `Left`.

  ## Protocols

  The `Left` and `Right` structs implement the following protocols, making the `Either` abstraction composable and extensible:

    - `Funx.Eq`: Enables equality comparisons between `Either` values.
    - `Funx.Foldable`: Implements `fold_l/3` and `fold_r/3` for reducing over contained values.
    - `Funx.Monad`: Provides `map/2`, `ap/2`, and `bind/2` for monadic composition.
    - `Funx.Ord`: Defines ordering behavior for comparing `Left` and `Right` values.

  Although these implementations are defined on each constructor (`Left` and `Right`), the behavior is consistent across the `Either` abstraction.

  This module helps you model failure explicitly, compose error-aware logic, and integrate cleanly with Elixir's functional idioms.
  """

  import Funx.Monad, only: [map: 2]

  import Funx.Foldable, only: [fold_l: 3]
  alias Funx.Either.{Left, Right}
  alias Funx.Eq
  alias Funx.Maybe
  alias Funx.Maybe.{Just, Nothing}

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
    fold_l(
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
    fold_l(
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
  Transforms the `Left` value using the given function if the `Either` is a `Left`.
  If the value is `Right`, it is returned unchanged.

  ## Examples

      iex> Funx.Either.map_left(Funx.Either.left("error"), fn e -> "wrapped: " <> e end)
      %Funx.Either.Left{left: "wrapped: error"}

      iex> Funx.Either.map_left(Funx.Either.right(42), fn _ -> "ignored" end)
      %Funx.Either.Right{right: 42}
  """
  @spec map_left(t(error, value), (error -> new_error)) :: t(new_error, value)
        when error: term(), new_error: term(), value: term()
  def map_left(%Left{left: error}, func) when is_function(func, 1), do: Left.pure(func.(error))
  def map_left(%Right{} = right, _func), do: right

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
    |> fold_l([], fn
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
    fold_l(list, [], fn item, acc ->
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

  def sequence_a(list) when is_list(list), do: traverse_a(list, fn x -> x end)

  @doc """
  Traverses a list, applying the given function to each element and collecting the results in a single `Right`.

  Unlike `traverse/2`, this version accumulates all `Left` values rather than stopping at the first failure.
  It is useful for validations where you want to gather all errors at once.

  ## Examples

      iex> validate = fn x -> Funx.Either.lift_predicate(x, &(&1 > 0), fn v -> "must be positive: \#{v}" end) end
      iex> Funx.Either.traverse_a([1, 2, 3], validate)
      %Funx.Either.Right{right: [1, 2, 3]}
      iex> Funx.Either.traverse_a([1, -2, -3], validate)
      %Funx.Either.Left{left: ["must be positive: -2", "must be positive: -3"]}
  """
  @spec traverse_a([a], (a -> t([e], b))) :: t([e], [b])
        when a: term(), b: term(), e: term()
  def traverse_a([], _func), do: right([])

  def traverse_a(list, func) when is_list(list) and is_function(func, 1) do
    fold_l(list, right([]), fn item, acc_result ->
      case {func.(item), acc_result} do
        {%Right{right: value}, %Right{right: acc}} ->
          right([value | acc])

        {%Left{left: new_errors}, %Left{left: existing_errors}} ->
          left(as_list(new_errors) ++ existing_errors)

        {%Right{}, %Left{left: existing_errors}} ->
          left(existing_errors)

        {%Left{left: errors}, %Right{}} ->
          left(as_list(errors))
      end
    end)
    |> map(&:lists.reverse/1)
    |> map_left(&:lists.reverse/1)
  end

  @doc """
  Traverses a list, applying the given function to each element, and collects the successful `Just` results into a single `Right`.

  The given function must return an `Either` of `Maybe`. `Right(Just x)` values are kept; `Right(Nothing)` values are filtered out.
  If any application returns `Left`, all `Left` values are accumulated.

  This is useful for effectful filtering, where you want to validate or transform elements and conditionally keep them, while still reporting all errors.

  ## Examples

      iex> filter_positive = fn x ->
      ...>   Funx.Either.lift_predicate(x, &is_integer/1, fn v -> "not an integer: \#{inspect(v)}" end)
      ...>   |> Funx.Monad.map(fn x -> if x > 0, do: Funx.Maybe.just(x), else: Funx.Maybe.nothing() end)
      ...> end
      iex> Funx.Either.wither_a([1, -2, 3], filter_positive)
      %Funx.Either.Right{right: [1, 3]}
      iex> Funx.Either.wither_a(["oops", -2], filter_positive)
      %Funx.Either.Left{left: ["not an integer: \\"oops\\""]}
  """

  @spec wither_a([a], (a -> t([e], Maybe.t(b)))) :: t([e], [b])
        when a: term(), b: term(), e: term()
  def wither_a([], _func), do: right([])

  def wither_a(list, func) when is_list(list) and is_function(func, 1) do
    fold_l(list, right([]), fn item, acc_result ->
      case {func.(item), acc_result} do
        {%Right{right: %Just{value: value}}, %Right{right: acc}} ->
          right([value | acc])

        {%Right{right: %Nothing{}}, %Right{right: acc}} ->
          right(acc)

        {%Left{left: new_errors}, %Left{left: existing_errors}} ->
          left(as_list(new_errors) ++ existing_errors)

        {%Right{}, %Left{left: existing_errors}} ->
          left(existing_errors)

        {%Left{left: errors}, %Right{}} ->
          left(as_list(errors))
      end
    end)
    |> map(&:lists.reverse/1)
    |> map_left(&:lists.reverse/1)
  end

  defp as_list(value) when is_list(value), do: value
  defp as_list(value), do: [value]

  @doc """
  Validates a value using a list of validator functions. Each validator returns an `Either`: a `Right` if the check passes, or a `Left` with an error.

  If any validator returns a `Left`, all errors are collected and returned in a `Left`. If all validators succeed, the original value is returned in a `Right`.

  ## Examples

      iex> validate_positive = fn x -> Funx.Either.lift_predicate(x, &(&1 > 0), fn v -> "Value must be positive: \#{v}" end) end
      iex> validate_even = fn x -> Funx.Either.lift_predicate(x, &rem(&1, 2) == 0, fn v -> "Value must be even: \#{v}" end) end
      iex> Funx.Either.validate(4, [validate_positive, validate_even])
      %Funx.Either.Right{right: 4}
      iex> Funx.Either.validate(3, [validate_positive, validate_even])
      %Funx.Either.Left{left: ["Value must be even: 3"]}
      iex> Funx.Either.validate(-3, [validate_positive, validate_even])
      %Funx.Either.Left{left: ["Value must be positive: -3", "Value must be even: -3"]}
  """
  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()

  def validate(value, validators) when is_list(validators) do
    traverse_a(validators, fn validator -> validator.(value) end)
    |> map(fn _ -> value end)
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{} -> right(value)
      %Left{left: error} -> left(List.wrap(error))
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
    |> fold_l(
      fn value -> Right.pure(value) end,
      fn -> Left.pure(on_none.()) end
    )
  end

  @doc """
  Lifts a value into an `Either` based on the result of a predicate.

  Returns `Right(value)` if the predicate returns `true`, or `Left(on_false.(value))` if it returns `false`.

  This allows you to wrap a conditional check in a functional context with a custom error message.

  ## Examples

      iex> Funx.Either.lift_predicate(5, fn x -> x > 3 end, fn x -> "\#{x} is too small" end)
      %Funx.Either.Right{right: 5}

      iex> Funx.Either.lift_predicate(2, fn x -> x > 3 end, fn x -> "\#{x} is too small" end)
      %Funx.Either.Left{left: "2 is too small"}
  """

  @spec lift_predicate(value, (value -> boolean), (value -> error)) :: t(error, value)
        when value: term(), error: term()
  def lift_predicate(value, predicate, on_false) do
    fold_l(
      fn -> predicate.(value) end,
      fn -> Right.pure(value) end,
      fn -> Left.pure(on_false.(value)) end
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
  Converts an `Either` to its inner value, raising an exception if it is `Left`.

  If the `Left` holds an exception struct, it is raised directly. If it holds a string or list of errors, they are converted into a `RuntimeError`. Unexpected types are inspected and raised as a `RuntimeError`.

  ## Examples

      iex> Funx.Either.to_try!(Funx.Either.right(5))
      5

      iex> Funx.Either.to_try!(Funx.Either.left("error"))
      ** (RuntimeError) error

      iex> Funx.Either.to_try!(Funx.Either.left(["error 1", "error 2"]))
      ** (RuntimeError) error 1, error 2

      iex> Funx.Either.to_try!(Funx.Either.left(%ArgumentError{message: "bad argument"}))
      ** (ArgumentError) bad argument
  """

  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(%Right{right: value}), do: value

  def to_try!(%Left{left: reason}) do
    raise normalize_reason(reason)
  end

  defp normalize_reason(%_{} = exception), do: exception
  defp normalize_reason(reason) when is_binary(reason), do: reason
  defp normalize_reason(reason) when is_list(reason), do: Enum.join(reason, ", ")
  defp normalize_reason(reason), do: "Unexpected error: #{inspect(reason)}"
end
