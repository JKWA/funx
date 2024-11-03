defmodule Monex.Either do
  @moduledoc """
  The `Monex.Either` module provides an implementation of the `Either` monad, which represents values that can either be `Right` (success) or `Left` (error).

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
    - `get_eq/1`: Returns a custom equality function for `Either` values.
    - `get_ord/1`: Returns a custom ordering function for `Either` values.

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

  import Monex.Monad, only: [bind: 2]
  import Monex.Foldable, only: [fold_r: 3]
  alias Monex.Either.{Left, Right}

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` monad.

  ## Examples

      iex> Monex.Either.right(5)
      %Monex.Either.Right{value: 5}
  """
  def right(value), do: Right.pure(value)

  @doc """
  Alias for `right/1`.
  """
  def pure(value), do: Right.pure(value)

  @doc """
  Wraps a value in the `Left` monad.

  ## Examples

      iex> Monex.Either.left("error")
      %Monex.Either.Left{value: "error"}
  """
  def left(value), do: Left.pure(value)

  @doc """
  Returns `true` if the `Either` is a `Left` value.

  ## Examples

      iex> Monex.Either.left?(Monex.Either.left("error"))
      true

      iex> Monex.Either.left?(Monex.Either.right(5))
      false
  """
  def left?(%Left{}), do: true
  def left?(_), do: false

  @doc """
  Returns `true` if the `Either` is a `Right` value.

  ## Examples

      iex> Monex.Either.right?(Monex.Either.right(5))
      true

      iex> Monex.Either.right?(Monex.Either.left("error"))
      false
  """
  def right?(%Right{}), do: true
  def right?(_), do: false

  @doc """
  Filters the value inside a `Right` using the given `predicate`. If the predicate returns `false`,
  a `Left` is returned using the `error_func`.

  ## Examples

      iex> Monex.Either.filter_or_else(Monex.Either.right(5), fn x -> x > 3 end, fn -> "error" end)
      %Monex.Either.Right{value: 5}

      iex> Monex.Either.filter_or_else(Monex.Either.right(2), fn x -> x > 3 end, fn -> "error" end)
      %Monex.Either.Left{value: "error"}
  """
  def filter_or_else(either, predicate, error_func) do
    fold_r(
      either,
      fn value ->
        if predicate.(value) do
          either
        else
          Left.pure(error_func.())
        end
      end,
      fn _left_value -> either end
    )
  end

  @doc """
  Retrieves the value from a `Right`, returning the `default` value if `Left`.

  ## Examples

      iex> Monex.Either.get_or_else(Monex.Either.right(5), 0)
      5

      iex> Monex.Either.get_or_else(Monex.Either.left("error"), 0)
      0
  """
  def get_or_else(either, default) do
    fold_r(
      either,
      fn value -> value end,
      fn _left_value -> default end
    )
  end

  @doc """
  Creates a custom ordering function for `Either` values using the provided `custom_ord`.

  ## Examples

      iex> ord = Monex.Either.get_ord(%{lt?: fn x, y -> x < y end})
      iex> ord.lt?.(Monex.Either.right(3), Monex.Either.right(5))
      true
  """
  def get_ord(custom_ord) do
    %{
      lt?: fn
        %Left{}, %Right{} -> true
        %Right{}, %Left{} -> false
        %Right{value: v1}, %Right{value: v2} -> custom_ord.lt?.(v1, v2)
        %Left{}, %Left{} -> false
      end,
      le?: fn a, b -> not get_ord(custom_ord).gt?.(a, b) end,
      gt?: fn
        %Right{}, %Left{} -> true
        %Left{}, %Right{} -> false
        %Right{value: v1}, %Right{value: v2} -> custom_ord.lt?.(v2, v1)
        %Left{}, %Left{} -> false
      end,
      ge?: fn a, b -> not get_ord(custom_ord).lt?.(a, b) end
    }
  end

  @doc """
  Sequences a list of `Either` values into an `Either` of a list.

  ## Examples

      iex> Monex.Either.sequence([Monex.Either.right(1), Monex.Either.right(2)])
      %Monex.Either.Right{value: [1, 2]}

      iex> Monex.Either.sequence([Monex.Either.right(1), Monex.Either.left("error")])
      %Monex.Either.Left{value: "error"}
  """
  @spec sequence([t(error, value)]) :: t(error, [value]) when error: term(), value: term()
  def sequence([]), do: right([])

  def sequence([head | tail]) do
    bind(head, fn value ->
      bind(sequence(tail), fn rest ->
        right([value | rest])
      end)
    end)
  end

  @doc """
  Applies a function to each element of a list and sequences the result.

  ## Examples

      iex> Monex.Either.traverse(&Monex.Either.right/1, [1, 2, 3])
      %Monex.Either.Right{value: [1, 2, 3]}
  """
  @spec traverse((a -> t(error, b)), [a]) :: t(error, [b])
        when error: term(), a: term(), b: term()
  def traverse(func, list) do
    list
    |> Enum.map(func)
    |> sequence()
  end

  @doc """
  Sequences a list of `Either` values, collecting all errors from `Left` values, rather than short-circuiting.

  ## Examples

      iex> Monex.Either.sequence_a([Monex.Either.right(1), Monex.Either.left("error"), Monex.Either.left("another error")])
      %Monex.Either.Left{value: ["error", "another error"]}
  """
  @spec sequence_a([t(error, value)]) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a([]), do: right([])

  def sequence_a([head | tail]) do
    case head do
      %Right{value: value} ->
        sequence_a(tail)
        |> case do
          %Right{value: values} -> right([value | values])
          %Left{value: errors} -> left(errors)
        end

      %Left{value: error} ->
        sequence_a(tail)
        |> case do
          %Right{value: _values} -> left([error])
          %Left{value: errors} -> left([error | errors])
        end
    end
  end

  @doc """
  Validates a value using a list of validators. Each validator is a function that returns an `Either` value.
  If any validator returns a `Left`, the errors are collected, and if all validators return `Right`, the value is returned in a `Right`.

  ## Examples

    ### Define Validators

        iex> validate_positive = fn x -> Monex.Either.lift_predicate(x, &(&1 > 0), fn -> "Value must be positive" end) end
        iex> validate_even = fn x -> Monex.Either.lift_predicate(x, &rem(&1, 2) == 0, fn -> "Value must be even" end) end
        iex> validators = [validate_positive, validate_even]

    ### Validate

        iex> Monex.Either.validate(4, validators)
        %Monex.Either.Right{value: 4}

        iex> Monex.Either.validate(3, validators)
        %Monex.Either.Left{value: ["Value must be even"]}

        iex> Monex.Either.validate(-3, validators)
        %Monex.Either.Left{value: ["Value must be positive", "Value must be even"]}
  """
  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()
  def validate(value, validators) when is_list(validators) do
    results = Enum.map(validators, fn validator -> validator.(value) end)

    case sequence_a(results) do
      %Right{} -> right(value)
      %Left{value: errors} -> left(errors)
    end
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{} -> right(value)
      %Left{value: error} -> left([error])
    end
  end

  @doc """
  Converts a `Maybe` value to an `Either`. If the `Maybe` is `Nothing`, a `Left` is returned using `on_none`.

  ## Examples

      iex> Monex.Either.lift_maybe(Monex.Maybe.just(5), fn -> "error" end)
      %Monex.Either.Right{value: 5}

      iex> Monex.Either.lift_maybe(Monex.Maybe.nothing(), fn -> "error" end)
      %Monex.Either.Left{value: "error"}
  """
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

      iex> Monex.Either.lift_predicate(5, fn x -> x > 3 end, fn -> "too small" end)
      %Monex.Either.Right{value: 5}

      iex> Monex.Either.lift_predicate(2, fn x -> x > 3 end, fn -> "too small" end)
      %Monex.Either.Left{value: "too small"}
  """
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

      iex> Monex.Either.from_result({:ok, 5})
      %Monex.Either.Right{value: 5}

      iex> Monex.Either.from_result({:error, "error"})
      %Monex.Either.Left{value: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}) :: t(left, right)
        when left: term(), right: term()
  def from_result({:ok, value}), do: Right.pure(value)
  def from_result({:error, reason}), do: Left.pure(reason)

  @doc """
  Converts an `Either` to a result (`{:ok, value}` or `{:error, reason}`).

  ## Examples

      iex> Monex.Either.to_result(Monex.Either.right(5))
      {:ok, 5}

      iex> Monex.Either.to_result(Monex.Either.left("error"))
      {:error, "error"}
  """
  @spec to_result(t(left, right)) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(either) do
    case either do
      %Right{value: value} -> {:ok, value}
      %Left{value: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a value in an `Either`, catching any exceptions. If an exception occurs, a `Left` is returned with the exception.

  ## Examples

      iex> Monex.Either.from_try(fn -> 5 end)
      %Monex.Either.Right{value: 5}

      iex> Monex.Either.from_try(fn -> raise "error" end)
      %Monex.Either.Left{value: %RuntimeError{message: "error"}}
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

      iex> Monex.Either.to_try!(Monex.Either.right(5))
      5

      iex> Monex.Either.to_try!(Monex.Either.left("error"))
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(either) do
    case either do
      %Right{value: value} ->
        value

      %Left{value: reason} ->
        raise reason
    end
  end
end
