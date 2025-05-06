defmodule Funx.Effect do
  @moduledoc """
  The `Funx.Effect` module provides an implementation of the `Effect` monad, which represents asynchronous computations that can either be `Right` (success) or `Left` (failure).

  `Effect` defers the execution of an effect until it is explicitly awaited, making it useful for handling asynchronous effects that may succeed or fail.

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
    - `traverse_a/2`: Traverses a list with a function that returns `Effect` values, accumulating all `Left` errors instead of stopping at the first.

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

  import Funx.Monad, only: [map: 2]
  import Funx.Foldable, only: [fold_l: 3]

  alias Funx.{Effect, Either, Maybe}
  alias Effect.{Left, Right}

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` monad, representing a successful computation.

  ## Examples

      iex> result = Funx.Effect.right(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec right(right) :: t(term(), right) when right: term()
  def right(value), do: Right.pure(value)

  @doc """
  Alias for `right/1`.

  ## Examples

      iex> result = Funx.Effect.pure(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec pure(right) :: t(term, right) when right: term()
  def pure(value), do: Right.pure(value)

  @doc """
  Wraps a value in the `Left` monad, representing a failed computation.

  ## Examples

      iex> result = Funx.Effect.left("error")
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec left(left) :: t(left, term()) when left: term()
  def left(value), do: Left.pure(value)

  @doc """
  Runs the `Effect` effect and returns the result, awaiting the effect if necessary.

  ## Examples

      iex> result = Funx.Effect.right(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec run(t(left, right), timeout()) :: Either.t(left, right)
        when left: term(), right: term()
  def run(effect, timeout \\ 5000)

  def run(%Right{effect: effect}, timeout),
    do: safe_await(effect.(), timeout)

  def run(%Left{effect: effect}, timeout),
    do: safe_await(effect.(), timeout)

  def safe_await(task, timeout \\ 5000) do
    try do
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, %Either.Right{} = right} -> right
        {:ok, %Either.Left{} = left} -> left
        {:ok, other} -> %Either.Left{left: {:invalid_result, other}}
        nil -> %Either.Left{left: :timeout}
      end
    rescue
      error -> %Either.Left{left: {:exception, error}}
    end
  end

  @doc """
  Lifts a value into the `Effect` monad based on a predicate.
  If the predicate returns true, the value is wrapped in `Right`.
  Otherwise, the result of calling `on_false` with the value is wrapped in `Left`.

  ## Examples

      iex> result = Funx.Effect.lift_predicate(10, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 10}

      iex> result = Funx.Effect.lift_predicate(3, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "3 is too small"}
  """
  @spec lift_predicate(term(), (term() -> boolean()), (term() -> left)) :: t(left, term())
        when left: term()
  def lift_predicate(value, predicate, on_false)
      when is_function(predicate, 1) and is_function(on_false, 1) do
    if predicate.(value) do
      Right.pure(value)
    else
      Left.pure(on_false.(value))
    end
  end

  @doc """
  Converts an `Either` value into a `Effect` monad.

  ## Examples

      iex> either = %Funx.Either.Right{right: 42}
      iex> result = Funx.Effect.lift_either(either)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> either = %Funx.Either.Left{left: "error"}
      iex> result = Funx.Effect.lift_either(either)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec lift_either(Either.t(left, right)) :: t(left, right) when left: term(), right: term()
  def lift_either(%Either.Right{right: right_value}) do
    Right.pure(right_value)
  end

  def lift_either(%Either.Left{left: left_value}) do
    Left.pure(left_value)
  end

  @doc """
  Converts a `Maybe` value into a `Effect` monad.
  If the `Maybe` is `Just`, the value is wrapped in `Right`.
  If it is `Nothing`, the value from `on_none` is wrapped in `Left`.

  ## Examples

      iex> maybe = Funx.Maybe.just(42)
      iex> result = Funx.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> maybe = Funx.Maybe.nothing()
      iex> result = Funx.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "No value"}
  """
  @spec lift_maybe(Maybe.t(right), (-> left)) :: t(left, right)
        when left: term(), right: term()
  def lift_maybe(maybe, on_none) do
    maybe
    |> fold_l(
      fn value -> Right.pure(value) end,
      fn -> Left.pure(on_none.()) end
    )
  end

  @doc """
  Transforms the `Left` branch of an `Effect`.

  If the `Effect` resolves to a `Left`, the provided function is applied to the error.
  If the `Effect` resolves to a `Right`, the value is returned unchanged.

  This function is useful when you want to rewrite or wrap errors without affecting successful computations.

  ## Examples

      iex> effect = Funx.Effect.left("error")
      iex> transformed = Funx.Effect.map_left(effect, fn e -> "wrapped: " <> e end)
      iex> Funx.Effect.run(transformed)
      %Funx.Either.Left{left: "wrapped: error"}

      iex> effect = Funx.Effect.pure(42)
      iex> transformed = Funx.Effect.map_left(effect, fn _ -> "should not be called" end)
      iex> Funx.Effect.run(transformed)
      %Funx.Either.Right{right: 42}
  """
  @spec map_left(t(error, value), (error -> new_error)) :: t(new_error, value)
        when error: term(), new_error: term(), value: term()
  def map_left(%Right{} = right, _func), do: right

  def map_left(%Left{effect: eff}, func) when is_function(func, 1) do
    %Left{
      effect: fn ->
        Task.async(fn ->
          case run(%Left{effect: eff}) do
            %Either.Left{left: error} -> %Either.Left{left: func.(error)}
            %Either.Right{} = right -> right
          end
        end)
      end
    }
  end

  @doc """
  Sequences a list of `Effect` values. If any value is `Left`, the sequencing stops
  and the first `Left` is returned. Otherwise, it returns a list of all `Right` values.

  ## Examples

      iex> effects = [Funx.Effect.right(1), Funx.Effect.right(2)]
      iex> result = Funx.Effect.sequence(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: [1, 2]}

      iex> effects = [Funx.Effect.right(1), Funx.Effect.left("error")]
      iex> result = Funx.Effect.sequence(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec sequence([t(left, right)]) :: t(left, [right]) when left: term(), right: term()
  def sequence(list) when is_list(list), do: traverse(list, fn x -> x end)

  @doc """
  Traverses a list with a function that returns `Effect` values,
  collecting the results into a single `Effect`.

  ## Examples

      iex> is_positive = fn num ->
      ...>   Funx.Effect.lift_predicate(num, fn x -> x > 0 end, fn x -> Integer.to_string(x) <> " is not positive" end)
      ...> end
      iex> result = Funx.Effect.traverse([1, 2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: [1, 2, 3]}
      iex> result = Funx.Effect.traverse([1, -2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "-2 is not positive"}
  """

  @spec traverse([input], (input -> t(left, right))) :: t(left, [right])
        when input: term(), left: term(), right: term()
  def traverse([], _func), do: pure([])

  def traverse(list, func) when is_list(list) and is_function(func, 1) do
    Enum.reduce_while(list, pure([]), fn item, %Right{} = acc ->
      case {func.(item), acc} do
        {%Right{effect: eff1}, %Right{effect: eff2}} ->
          {:cont,
           %Right{
             effect: fn ->
               Task.async(fn ->
                 with %Either.Right{right: val} <- run(%Right{effect: eff1}),
                      %Either.Right{right: acc_vals} <- run(%Right{effect: eff2}) do
                   %Either.Right{right: [val | acc_vals]}
                 end
               end)
             end
           }}

        {%Left{} = left, _} ->
          {:halt, left}
      end
    end)
    |> map(&:lists.reverse/1)
  end

  @doc """
  Sequences a list of `Effect` values, accumulating all errors in case of multiple `Left` values.

  ## Examples

      iex> effects = [Funx.Effect.right(1), Funx.Effect.left("Error 1"), Funx.Effect.left("Error 2")]
      iex> result = Funx.Effect.sequence_a(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Error 1", "Error 2"]}
  """
  @spec sequence_a([t(error, value)]) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a(list) when is_list(list), do: traverse_a(list, fn x -> x end)

  @spec traverse_a([input], (input -> t(error, value))) :: t([error], [value])
        when input: term(), error: term(), value: term()
  def traverse_a([], _func), do: right([])

  def traverse_a(list, func) when is_list(list) and is_function(func, 1) do
    fold_l(list, right([]), fn item, acc_result ->
      case {func.(item), acc_result} do
        {%Right{effect: eff1}, %Right{effect: eff2}} ->
          %Right{
            effect: fn ->
              Task.async(fn ->
                with %Either.Right{right: val} <- run(%Right{effect: eff1}),
                     %Either.Right{right: acc} <- run(%Right{effect: eff2}) do
                  %Either.Right{right: [val | acc]}
                end
              end)
            end
          }

        {%Left{effect: eff1}, %Left{effect: eff2}} ->
          %Left{
            effect: fn ->
              Task.async(fn ->
                %Either.Left{
                  left:
                    as_list(run(%Left{effect: eff1}).left) ++
                      as_list(run(%Left{effect: eff2}).left)
                }
              end)
            end
          }

        {%Right{}, %Left{effect: eff2}} ->
          %Left{
            effect: fn ->
              Task.async(fn -> run(%Left{effect: eff2}) end)
            end
          }

        {%Left{effect: eff1}, %Right{}} ->
          %Left{
            effect: fn ->
              Task.async(fn ->
                %Either.Left{left: as_list(run(%Left{effect: eff1}).left)}
              end)
            end
          }
      end
    end)
    |> map(&:lists.reverse/1)
    |> map_left(&:lists.reverse/1)
  end

  defp as_list(val) when is_list(val), do: val
  defp as_list(val), do: [val]

  @doc """
  Validates a value using a list of validators. Each validator is a function that returns an `Effect` value.
  If any validator returns a `Left`, the errors are collected. If all validators return `Right`, the value is returned in a `Right`.

  ## Examples

      iex> validate_positive = fn value ->
      ...>   Funx.Effect.lift_predicate(value, fn x -> x > 0 end, fn x -> "Value " <> Integer.to_string(x) <> " must be positive" end)
      ...> end
      iex> validate_even = fn value ->
      ...>   Funx.Effect.lift_predicate(value, fn x -> rem(x, 2) == 0 end, fn x -> "Value " <> Integer.to_string(x) <> " must be even" end)
      ...> end
      iex> validators = [validate_positive, validate_even]
      iex> result = Funx.Effect.validate(4, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 4}
      iex> result = Funx.Effect.validate(3, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Value 3 must be even"]}
      iex> result = Funx.Effect.validate(-3, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Value -3 must be positive", "Value -3 must be even"]}
  """
  @spec validate(value, [(value -> t(error, any))]) :: t([error], value)
        when error: term(), value: term()
  def validate(value, validators) when is_list(validators) do
    traverse_a(validators, fn validator -> validator.(value) end)
    |> map(fn _ -> value end)
  end

  def validate(value, validator) when is_function(validator, 1) do
    case validator.(value) do
      %Right{} = right_effect ->
        map(right_effect, fn _ -> value end)

      %Left{} = left_effect ->
        map_left(left_effect, &List.wrap/1)
    end
  end

  @doc """
  Converts an Elixir `{:ok, value}` or `{:error, reason}` tuple into a `Effect`.

  ## Examples

      iex> result = Funx.Effect.from_result({:ok, 42})
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> result = Funx.Effect.from_result({:error, "error"})
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}) :: t(left, right)
        when left: term(), right: term()
  def from_result({:ok, value}), do: Right.pure(value)
  def from_result({:error, reason}), do: Left.pure(reason)

  @doc """
  Converts a `Effect` monad into an Elixir result tuple.

  ## Examples

      iex> effect_result = Funx.Effect.right(42)
      iex> Funx.Effect.to_result(effect_result)
      {:ok, 42}

      iex> effect_error = Funx.Effect.left("error")
      iex> Funx.Effect.to_result(effect_error)
      {:error, "error"}
  """
  @spec to_result(t(left, right)) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(effect) do
    case run(effect) do
      %Either.Right{right: value} -> {:ok, value}
      %Either.Left{left: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a function in a `Effect`, catching exceptions and wrapping them in a `Left`.

  ## Examples

      iex> result = Funx.Effect.from_try(fn -> 42 end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> result = Funx.Effect.from_try(fn -> raise "error" end)
      iex> Funx.Effect.run(result)
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
  Unwraps a `Effect`, returning the value if it is a `Right`, or raising the exception if it is a `Left`.

  ## Examples

      iex> effect_result = Funx.Effect.right(42)
      iex> Funx.Effect.to_try!(effect_result)
      42

      iex> effect_error = Funx.Effect.left(%RuntimeError{message: "error"})
      iex> Funx.Effect.to_try!(effect_error)
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(effect) do
    case run(effect) do
      %Either.Right{right: value} -> value
      %Either.Left{left: reason} -> raise reason
    end
  end
end
