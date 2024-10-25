defmodule Monex.LazyTaskEither do
  @moduledoc """
  The `Monex.LazyTaskEither` module provides an implementation of the `LazyTaskEither` monad, which represents asynchronous computations that can either be `Right` (success) or `Left` (failure).

  `LazyTaskEither` defers the execution of a task until it is explicitly awaited, making it useful for handling asynchronous tasks that may succeed or fail.

  ### Constructors
    - `right/1`: Wraps a value in the `Right` monad.
    - `left/1`: Wraps a value in the `Left` monad.
    - `pure/1`: Alias for `right/1`.

  ### Execution
    - `run/1`: Executes the deferred task inside the `LazyTaskEither` monad and returns its result (`Right` or `Left`).

  ### Sequencing
    - `sequence/1`: Sequences a list of `LazyTaskEither` values, returning a list of `Right` values or the first `Left`.
    - `traverse/2`: Traverses a list with a function that returns `LazyTaskEither` values, collecting the results into a single `LazyTaskEither`.
    - `sequence_a/1`: Sequences a list of `LazyTaskEither` values, collecting all `Left` errors.

  ### Validation
    - `validate/2`: Validates a value using a list of validators, collecting errors from `Left` values.

  ### Lifts
    - `lift_either/1`: Lifts an `Either` value to a `LazyTaskEither` monad.
    - `lift_option/2`: Lifts a `Maybe` value to a `LazyTaskEither` monad.
    - `lift_predicate/3`: Lifts a value into a `LazyTaskEither` based on a predicate.

  ### Elixir Interops
    - `from_result/1`: Converts a result (`{:ok, _}` or `{:error, _}`) to a `LazyTaskEither`.
    - `to_result/1`: Converts a `LazyTaskEither` to a result (`{:ok, value}` or `{:error, reason}`).
    - `from_try/1`: Wraps a function in a `LazyTaskEither`, catching exceptions.
    - `to_try!/1`: Converts a `LazyTaskEither` to its value or raises an exception if `Left`.
  """

  import Monex.Monad, only: [ap: 2, map: 2]
  import Monex.Foldable, only: [fold_r: 3]

  alias Monex.{Either, Maybe, LazyTaskEither}
  alias LazyTaskEither.{Right, Left}

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` monad, representing a successful computation.

  ## Examples

      iex> result = Monex.LazyTaskEither.right(42)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec right(right) :: t(term(), right) when right: term()
  def right(value), do: Right.pure(value)

  @doc """
  Alias for `right/1`.

  ## Examples

      iex> result = Monex.LazyTaskEither.pure(42)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec pure(right) :: t(term, right) when right: term()
  def pure(value), do: Right.pure(value)

  @doc """
  Wraps a value in the `Left` monad, representing a failed computation.

  ## Examples

      iex> result = Monex.LazyTaskEither.left("error")
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec left(left) :: t(left, term()) when left: term()
  def left(value), do: Left.pure(value)

  @doc """
  Runs the `LazyTaskEither` task and returns the result, awaiting the task if necessary.

  ## Examples

      iex> result = Monex.LazyTaskEither.right(42)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec run(t(left, right)) :: left | right when left: term(), right: term()
  def run(%Right{task: task}) do
    Task.await(task.())
  end

  def run(%Left{task: task}) do
    Task.await(task.())
  end

  @doc """
  Lifts a value into the `LazyTaskEither` monad based on a predicate.
  If the predicate returns true, the value is wrapped in `Right`.
  Otherwise, the value from `on_false` is wrapped in `Left`.

  ## Examples

      iex> result = Monex.LazyTaskEither.lift_predicate(10, &(&1 > 5), fn -> "too small" end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 10}

      iex> result = Monex.LazyTaskEither.lift_predicate(3, &(&1 > 5), fn -> "too small" end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "too small"}
  """
  @spec lift_predicate(term(), (term() -> boolean()), (-> left)) :: t(left, term())
        when left: term()
  def lift_predicate(value, predicate, on_false) do
    if predicate.(value) do
      Right.pure(value)
    else
      Left.pure(on_false.())
    end
  end

  @doc """
  Converts an `Either` value into a `LazyTaskEither` monad.

  ## Examples

      iex> either = %Monex.Either.Right{value: 42}
      iex> result = Monex.LazyTaskEither.lift_either(either)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}

      iex> either = %Monex.Either.Left{value: "error"}
      iex> result = Monex.LazyTaskEither.lift_either(either)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec lift_either(Either.t(left, right)) :: t(left, right) when left: term(), right: term()
  def lift_either(%Either.Right{value: right_value}) do
    Right.pure(right_value)
  end

  def lift_either(%Either.Left{value: left_value}) do
    Left.pure(left_value)
  end

  @doc """
  Converts a `Maybe` value into a `LazyTaskEither` monad.
  If the `Maybe` is `Just`, the value is wrapped in `Right`.
  If it is `Nothing`, the value from `on_none` is wrapped in `Left`.

  ## Examples

      iex> maybe = Monex.Maybe.just(42)
      iex> result = Monex.LazyTaskEither.lift_option(maybe, fn -> "No value" end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}

      iex> maybe = Monex.Maybe.nothing()
      iex> result = Monex.LazyTaskEither.lift_option(maybe, fn -> "No value" end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "No value"}
  """
  @spec lift_option(Maybe.t(right), (-> left)) :: t(left, right)
        when left: term(), right: term()
  def lift_option(maybe, on_none) do
    maybe
    |> fold_r(
      fn value -> Right.pure(value) end,
      fn -> Left.pure(on_none.()) end
    )
  end

  @doc """
  Sequences a list of `LazyTaskEither` values. If any value is `Left`, the sequencing stops
  and the first `Left` is returned. Otherwise, it returns a list of all `Right` values.

  ## Examples

      iex> tasks = [Monex.LazyTaskEither.right(1), Monex.LazyTaskEither.right(2)]
      iex> result = Monex.LazyTaskEither.sequence(tasks)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: [1, 2]}

      iex> tasks = [Monex.LazyTaskEither.right(1), Monex.LazyTaskEither.left("error")]
      iex> result = Monex.LazyTaskEither.sequence(tasks)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec sequence([t(left, right)]) :: t(left, [right]) when left: term(), right: term()
  def sequence(list) do
    Enum.reduce_while(list, Right.pure([]), fn
      %Left{} = left, _acc ->
        {:halt, left}

      %Right{} = right, acc ->
        {:cont, ap(map(acc, fn acc_value -> fn value -> [value | acc_value] end end), right)}
    end)
    |> map(&Enum.reverse/1)
  end

  @doc """
  Traverses a list with a function that returns `LazyTaskEither` values,
  collecting the results into a single `LazyTaskEither`.

  ## Examples

      iex> is_positive = fn num -> Monex.LazyTaskEither.lift_predicate(num, fn x -> x > 0 end, fn -> Integer.to_string(num) <> " is not positive" end) end
      iex> result = Monex.LazyTaskEither.traverse([1, 2, 3], fn num -> is_positive.(num) end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: [1, 2, 3]}

      iex> result = Monex.LazyTaskEither.traverse([1, -2, 3], fn num -> is_positive.(num) end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "-2 is not positive"}
  """

  @spec traverse([input], (input -> t(left, right))) :: t(left, [right])
        when input: term(), left: term(), right: term()
  def traverse(list, func) do
    list
    |> Enum.map(func)
    |> sequence()
  end

  @doc """
  Sequences a list of `LazyTaskEither` values, accumulating all errors in case of multiple `Left` values.

  ## Examples

      iex> tasks = [Monex.LazyTaskEither.right(1), Monex.LazyTaskEither.left("Error 1"), Monex.LazyTaskEither.left("Error 2")]
      iex> result = Monex.LazyTaskEither.sequence_a(tasks)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: ["Error 1", "Error 2"]}
  """
  @spec sequence_a([t(error, value)]) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a([]), do: right([])

  def sequence_a([head | tail]) do
    case Task.await(head.task.()) do
      %Either.Right{value: value} ->
        sequence_a(tail)
        |> case do
          %Right{task: task} ->
            %Right{
              task: fn ->
                Task.async(fn ->
                  %Either.Right{value: [value | Task.await(task.()).value]}
                end)
              end
            }

          %Left{task: task} ->
            %Left{task: task}
        end

      %Either.Left{value: error} ->
        sequence_a(tail)
        |> case do
          %Right{} ->
            %Left{
              task: fn ->
                Task.async(fn -> %Either.Left{value: [error]} end)
              end
            }

          %Left{task: task} ->
            %Left{
              task: fn ->
                Task.async(fn -> %Either.Left{value: [error | Task.await(task.()).value]} end)
              end
            }
        end
    end
  end

  @doc """
  Validates a value using a list of validators. Each validator is a function that returns a `LazyTaskEither` value.
  If any validator returns a `Left`, the errors are collected, and if all validators return `Right`, the value is returned in a `Right`.

  ## Examples

    ### Define Validators

        iex> validate_positive = fn value -> Monex.LazyTaskEither.lift_predicate(value, &(&1 > 0), fn -> "Value must be positive" end) end
        iex> validate_even = fn value -> Monex.LazyTaskEither.lift_predicate(value, &rem(&1, 2) == 0, fn -> "Value must be even" end) end
        iex> validators = [validate_positive, validate_even]

    ### Validate

        iex> result = Monex.LazyTaskEither.validate(4, validators)
        iex> Monex.LazyTaskEither.run(result)
        %Monex.Either.Right{value: 4}

        iex> result = Monex.LazyTaskEither.validate(3, validators)
        iex> Monex.LazyTaskEither.run(result)
        %Monex.Either.Left{value: ["Value must be even"]}

        iex> result = Monex.LazyTaskEither.validate(-3, validators)
        iex> Monex.LazyTaskEither.run(result)
        %Monex.Either.Left{value: ["Value must be positive", "Value must be even"]}
  """

  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()
  def validate(value, validators) when is_list(validators) do
    results = Enum.map(validators, fn validator -> validator.(value) end)

    case sequence_a(results) do
      %Right{task: _task} ->
        %Right{
          task: fn ->
            Task.async(fn ->
              %Either.Right{value: value}
            end)
          end
        }

      %Left{task: task} ->
        %Left{
          task: fn ->
            Task.async(fn ->
              %Either.Left{value: Task.await(task.()).value}
            end)
          end
        }
    end
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{task: _task} ->
        %Right{
          task: fn ->
            Task.async(fn -> %Either.Right{value: value} end)
          end
        }

      %Left{task: task} ->
        %Left{
          task: fn ->
            Task.async(fn -> %Either.Left{value: [Task.await(task.()).value]} end)
          end
        }
    end
  end

  @doc """
  Converts an Elixir `{:ok, value}` or `{:error, reason}` tuple into a `LazyTaskEither`.

  ## Examples

      iex> result = Monex.LazyTaskEither.from_result({:ok, 42})
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}

      iex> result = Monex.LazyTaskEither.from_result({:error, "error"})
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}) :: t(left, right)
        when left: term(), right: term()
  def from_result({:ok, value}), do: Right.pure(value)
  def from_result({:error, reason}), do: Left.pure(reason)

  @doc """
  Converts a `LazyTaskEither` monad into an Elixir result tuple.

  ## Examples

      iex> lazy_result = Monex.LazyTaskEither.right(42)
      iex> Monex.LazyTaskEither.to_result(lazy_result)
      {:ok, 42}

      iex> lazy_error = Monex.LazyTaskEither.left("error")
      iex> Monex.LazyTaskEither.to_result(lazy_error)
      {:error, "error"}
  """
  @spec to_result(t(left, right)) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(lazy_task_either) do
    case run(lazy_task_either) do
      %Either.Right{value: value} -> {:ok, value}
      %Either.Left{value: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a function in a `LazyTaskEither`, catching exceptions and wrapping them in a `Left`.

  ## Examples

      iex> result = Monex.LazyTaskEither.from_try(fn -> 42 end)
      iex> Monex.LazyTaskEither.run(result)
      %Monex.Either.Right{value: 42}

      iex> result = Monex.LazyTaskEither.from_try(fn -> raise "error" end)
      iex> Monex.LazyTaskEither.run(result)
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
  Unwraps a `LazyTaskEither`, returning the value if it is a `Right`, or raising the exception if it is a `Left`.

  ## Examples

      iex> lazy_result = Monex.LazyTaskEither.right(42)
      iex> Monex.LazyTaskEither.to_try!(lazy_result)
      42

      iex> lazy_error = Monex.LazyTaskEither.left(%RuntimeError{message: "error"})
      iex> Monex.LazyTaskEither.to_try!(lazy_error)
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(lazy_task_either) do
    case run(lazy_task_either) do
      %Either.Right{value: value} -> value
      %Either.Left{value: reason} -> raise reason
    end
  end
end
