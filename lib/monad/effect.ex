defmodule Monex.Effect do
  @moduledoc """
  The `Monex.Effect` module provides an implementation of the `Effect` monad, which represents asynchronous computations that can either be `Right` (success) or `Left` (failure).

  `Effect` defers the execution of a effect until it is explicitly awaited, making it useful for handling asynchronous effects that may succeed or fail.

  ### Constructors
    - `right/1`: Wraps a value in the `Right` monad.
    - `left/1`: Wraps a value in the `Left` monad.
    - `pure/1`: Alias for `right/1`.

  ### Execution
    - `run/1`: Executes the deferred effect inside the `Effect` monad and returns its result (`Right` or `Left`).

  ### Sequencing
    - `sequence/1`: Sequences a list of `Effect` values, returning a list of `Right` values or the first `Left`.
    - `traverse/2`: Traverses a list with a function that returns `Effect` values, collecting the results into a single `Effect`.
    - `sequence_a/1`: Sequences a list of `Effect` values, collecting all `Left` errors.

  ### Validation
    - `validate/2`: Validates a value using a list of validators, collecting errors from `Left` values.

  ### Lifts
    - `lift_either/1`: Lifts an `Either` value to a `Effect` monad.
    - `lift_maybe/2`: Lifts a `Maybe` value to a `Effect` monad.
    - `lift_predicate/3`: Lifts a value into a `Effect` based on a predicate.

  ### Elixir Interops
    - `from_result/1`: Converts a result (`{:ok, _}` or `{:error, _}`) to a `Effect`.
    - `to_result/1`: Converts a `Effect` to a result (`{:ok, value}` or `{:error, reason}`).
    - `from_try/1`: Wraps a function in a `Effect`, catching exceptions.
    - `to_try!/1`: Converts a `Effect` to its value or raises an exception if `Left`.
  """

  import Monex.Monad, only: [ap: 2, map: 2]
  import Monex.Foldable, only: [fold_r: 3]

  alias Monex.{Effect, Either, Maybe}
  alias Effect.{Left, Right}

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` monad, representing a successful computation.

  ## Examples

      iex> result = Monex.Effect.right(42)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec right(right) :: t(term(), right) when right: term()
  def right(value), do: Right.pure(value)

  @doc """
  Alias for `right/1`.

  ## Examples

      iex> result = Monex.Effect.pure(42)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec pure(right) :: t(term, right) when right: term()
  def pure(value), do: Right.pure(value)

  @doc """
  Wraps a value in the `Left` monad, representing a failed computation.

  ## Examples

      iex> result = Monex.Effect.left("error")
      iex> Monex.Effect.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec left(left) :: t(left, term()) when left: term()
  def left(value), do: Left.pure(value)

  @doc """
  Runs the `Effect` effect and returns the result, awaiting the effect if necessary.

  ## Examples

      iex> result = Monex.Effect.right(42)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}
  """
  @spec run(t(left, right)) :: left | right when left: term(), right: term()
  def run(%Right{effect: effect}) do
    Task.await(effect.())
  end

  def run(%Left{effect: effect}) do
    Task.await(effect.())
  end

  @doc """
  Lifts a value into the `Effect` monad based on a predicate.
  If the predicate returns true, the value is wrapped in `Right`.
  Otherwise, the value from `on_false` is wrapped in `Left`.

  ## Examples

      iex> result = Monex.Effect.lift_predicate(10, &(&1 > 5), fn -> "too small" end)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 10}

      iex> result = Monex.Effect.lift_predicate(3, &(&1 > 5), fn -> "too small" end)
      iex> Monex.Effect.run(result)
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
  Converts an `Either` value into a `Effect` monad.

  ## Examples

      iex> either = %Monex.Either.Right{value: 42}
      iex> result = Monex.Effect.lift_either(either)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}

      iex> either = %Monex.Either.Left{value: "error"}
      iex> result = Monex.Effect.lift_either(either)
      iex> Monex.Effect.run(result)
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
  Converts a `Maybe` value into a `Effect` monad.
  If the `Maybe` is `Just`, the value is wrapped in `Right`.
  If it is `Nothing`, the value from `on_none` is wrapped in `Left`.

  ## Examples

      iex> maybe = Monex.Maybe.just(42)
      iex> result = Monex.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}

      iex> maybe = Monex.Maybe.nothing()
      iex> result = Monex.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Monex.Effect.run(result)
      %Monex.Either.Left{value: "No value"}
  """
  @spec lift_maybe(Maybe.t(right), (-> left)) :: t(left, right)
        when left: term(), right: term()
  def lift_maybe(maybe, on_none) do
    maybe
    |> fold_r(
      fn value -> Right.pure(value) end,
      fn -> Left.pure(on_none.()) end
    )
  end

  @doc """
  Sequences a list of `Effect` values. If any value is `Left`, the sequencing stops
  and the first `Left` is returned. Otherwise, it returns a list of all `Right` values.

  ## Examples

      iex> effects = [Monex.Effect.right(1), Monex.Effect.right(2)]
      iex> result = Monex.Effect.sequence(effects)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: [1, 2]}

      iex> effects = [Monex.Effect.right(1), Monex.Effect.left("error")]
      iex> result = Monex.Effect.sequence(effects)
      iex> Monex.Effect.run(result)
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
  Traverses a list with a function that returns `Effect` values,
  collecting the results into a single `Effect`.

  ## Examples

      iex> is_positive = fn num -> Monex.Effect.lift_predicate(num, fn x -> x > 0 end, fn -> Integer.to_string(num) <> " is not positive" end) end
      iex> result = Monex.Effect.traverse([1, 2, 3], fn num -> is_positive.(num) end)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: [1, 2, 3]}

      iex> result = Monex.Effect.traverse([1, -2, 3], fn num -> is_positive.(num) end)
      iex> Monex.Effect.run(result)
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
  Sequences a list of `Effect` values, accumulating all errors in case of multiple `Left` values.

  ## Examples

      iex> effects = [Monex.Effect.right(1), Monex.Effect.left("Error 1"), Monex.Effect.left("Error 2")]
      iex> result = Monex.Effect.sequence_a(effects)
      iex> Monex.Effect.run(result)
      %Monex.Either.Left{value: ["Error 1", "Error 2"]}
  """
  @spec sequence_a([t(error, value)]) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a([]), do: right([])

  def sequence_a([head | tail]) do
    case Task.await(head.effect.()) do
      %Either.Right{value: value} ->
        sequence_a(tail)
        |> case do
          %Right{effect: effect} ->
            %Right{
              effect: fn ->
                Task.async(fn ->
                  %Either.Right{value: [value | Task.await(effect.()).value]}
                end)
              end
            }

          %Left{effect: effect} ->
            %Left{effect: effect}
        end

      %Either.Left{value: error} ->
        sequence_a(tail)
        |> case do
          %Right{} ->
            %Left{
              effect: fn ->
                Task.async(fn -> %Either.Left{value: [error]} end)
              end
            }

          %Left{effect: effect} ->
            %Left{
              effect: fn ->
                Task.async(fn -> %Either.Left{value: [error | Task.await(effect.()).value]} end)
              end
            }
        end
    end
  end

  @doc """
  Validates a value using a list of validators. Each validator is a function that returns a `Effect` value.
  If any validator returns a `Left`, the errors are collected, and if all validators return `Right`, the value is returned in a `Right`.

  ## Examples

    ### Define Validators

        iex> validate_positive = fn value -> Monex.Effect.lift_predicate(value, &(&1 > 0), fn -> "Value must be positive" end) end
        iex> validate_even = fn value -> Monex.Effect.lift_predicate(value, &rem(&1, 2) == 0, fn -> "Value must be even" end) end
        iex> validators = [validate_positive, validate_even]

    ### Validate

        iex> result = Monex.Effect.validate(4, validators)
        iex> Monex.Effect.run(result)
        %Monex.Either.Right{value: 4}

        iex> result = Monex.Effect.validate(3, validators)
        iex> Monex.Effect.run(result)
        %Monex.Either.Left{value: ["Value must be even"]}

        iex> result = Monex.Effect.validate(-3, validators)
        iex> Monex.Effect.run(result)
        %Monex.Either.Left{value: ["Value must be positive", "Value must be even"]}
  """

  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()
  def validate(value, validators) when is_list(validators) do
    results = Enum.map(validators, fn validator -> validator.(value) end)

    case sequence_a(results) do
      %Right{effect: _effect} ->
        %Right{
          effect: fn ->
            Task.async(fn ->
              %Either.Right{value: value}
            end)
          end
        }

      %Left{effect: effect} ->
        %Left{
          effect: fn ->
            Task.async(fn ->
              %Either.Left{value: Task.await(effect.()).value}
            end)
          end
        }
    end
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{effect: _effect} ->
        %Right{
          effect: fn ->
            Task.async(fn -> %Either.Right{value: value} end)
          end
        }

      %Left{effect: effect} ->
        %Left{
          effect: fn ->
            Task.async(fn -> %Either.Left{value: [Task.await(effect.()).value]} end)
          end
        }
    end
  end

  @doc """
  Converts an Elixir `{:ok, value}` or `{:error, reason}` tuple into a `Effect`.

  ## Examples

      iex> result = Monex.Effect.from_result({:ok, 42})
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}

      iex> result = Monex.Effect.from_result({:error, "error"})
      iex> Monex.Effect.run(result)
      %Monex.Either.Left{value: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}) :: t(left, right)
        when left: term(), right: term()
  def from_result({:ok, value}), do: Right.pure(value)
  def from_result({:error, reason}), do: Left.pure(reason)

  @doc """
  Converts a `Effect` monad into an Elixir result tuple.

  ## Examples

      iex> effect_result = Monex.Effect.right(42)
      iex> Monex.Effect.to_result(effect_result)
      {:ok, 42}

      iex> effect_error = Monex.Effect.left("error")
      iex> Monex.Effect.to_result(effect_error)
      {:error, "error"}
  """
  @spec to_result(t(left, right)) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(effect) do
    case run(effect) do
      %Either.Right{value: value} -> {:ok, value}
      %Either.Left{value: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a function in a `Effect`, catching exceptions and wrapping them in a `Left`.

  ## Examples

      iex> result = Monex.Effect.from_try(fn -> 42 end)
      iex> Monex.Effect.run(result)
      %Monex.Either.Right{value: 42}

      iex> result = Monex.Effect.from_try(fn -> raise "error" end)
      iex> Monex.Effect.run(result)
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
  Unwraps a `Effect`, returning the value if it is a `Right`, or raising the exception if it is a `Left`.

  ## Examples

      iex> effect_result = Monex.Effect.right(42)
      iex> Monex.Effect.to_try!(effect_result)
      42

      iex> effect_error = Monex.Effect.left(%RuntimeError{message: "error"})
      iex> Monex.Effect.to_try!(effect_error)
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(effect) do
    case run(effect) do
      %Either.Right{value: value} -> value
      %Either.Left{value: reason} -> raise reason
    end
  end
end
