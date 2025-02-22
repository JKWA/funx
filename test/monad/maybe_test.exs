defmodule Monex.MaybeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  doctest Monex.Maybe
  doctest Monex.Maybe.Just
  doctest Monex.Maybe.Nothing

  import Monex.Foldable, only: [fold_l: 3, fold_r: 3]
  import Monex.Maybe
  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]

  alias Monex.{Either, Eq, Ord}
  alias Monex.Identity
  alias Monex.Maybe.{Just, Nothing}

  describe "Just.pure/1" do
    test "wraps a non-nil value in a Just monad" do
      assert %Just{value: 42} = pure(42)
    end

    test "raises an error when wrapping nil" do
      assert_raise ArgumentError, "Cannot wrap nil in a Just", fn ->
        pure(nil)
      end
    end
  end

  describe "just/1" do
    test "returns the Nothing struct" do
      assert %Just{value: 42} = just(42)
    end

    test "raises an error when wrapping nil" do
      assert_raise ArgumentError, "Cannot wrap nil in a Just", fn ->
        just(nil)
      end
    end
  end

  describe "Nothing.pure/0" do
    test "returns the Nothing struct" do
      assert %Nothing{} = nothing()
    end
  end

  describe "map/2" do
    test "applies a function to the value inside a Just monad" do
      assert %Just{value: 43} =
               just(42)
               |> map(&(&1 + 1))
    end

    test "returns Nothing when mapping over a Nothing monad" do
      assert %Nothing{} =
               nothing()
               |> map(&(&1 + 1))
    end
  end

  describe "bind/2" do
    test "applies a function returning a monad to the value inside a Just monad" do
      assert %Just{value: 21} =
               just(42)
               |> bind(fn x -> just(div(x, 2)) end)
    end

    test "returns Nothing when binding over a Nothing monad" do
      assert %Nothing{} =
               nothing()
               |> bind(fn _ -> just(10) end)
    end

    test "returns Nothing when the function returns Nothing" do
      assert %Nothing{} =
               just(42)
               |> bind(fn _ -> nothing() end)
    end
  end

  describe "ap/2" do
    test "applies a function in Just to a value in Just" do
      assert ap(just(&(&1 + 1)), just(42)) == just(43)
    end

    test "returns Nothing if the function is in Nothing" do
      assert ap(nothing(), just(42)) == nothing()
    end

    test "returns Nothing if the value is in Nothing" do
      assert ap(just(&(&1 + 1)), nothing()) == nothing()
    end

    test "returns Nothing if both are Nothing" do
      assert ap(nothing(), nothing()) == nothing()
    end
  end

  describe "fold_r/3" do
    test "applies the just_func to a Just value" do
      result =
        just(42)
        |> fold_r(fn x -> "Just #{x}" end, fn -> "Nothing" end)

      assert result == "Just 42"
    end

    test "applies the nothing_func to a Nothing value" do
      result =
        nothing()
        |> fold_r(fn x -> "Just #{x}" end, fn -> "Nothing" end)

      assert result == "Nothing"
    end
  end

  describe "fold_l/3" do
    test "applies the just_func to a Just value" do
      result =
        just(42)
        |> fold_l(fn x -> "Just #{x}" end, fn -> "Nothing" end)

      assert result == "Just 42"
    end

    test "applies the nothing_func to a Nothing value" do
      result =
        nothing()
        |> fold_l(fn x -> "Just #{x}" end, fn -> "Nothing" end)

      assert result == "Nothing"
    end
  end

  describe "just?/1" do
    test "returns true for Just values" do
      assert just?(just(42)) == true
    end

    test "returns false for Nothing values" do
      assert just?(nothing()) == false
    end
  end

  describe "nothing?/1" do
    test "returns true for Nothing values" do
      assert nothing?(nothing()) == true
    end

    test "returns false for Just values" do
      assert nothing?(just(42)) == false
    end
  end

  describe "String.Chars" do
    test "Just value string representation" do
      just_value = just(42)
      assert to_string(just_value) == "Just(42)"
    end

    test "Nothing value string representation" do
      nothing_value = nothing()
      assert to_string(nothing_value) == "Nothing"
    end
  end

  describe "get_or_else/2" do
    test "returns the value in Just when present" do
      assert just(42) |> get_or_else(0) == 42
    end

    test "returns the default value when Nothing" do
      assert nothing() |> get_or_else(0) == 0
    end
  end

  describe "guard/2" do
    test "returns Just value when boolean is true" do
      maybe_value = just(42)
      assert guard(maybe_value, true) == maybe_value
    end

    test "returns Nothing when boolean is false" do
      maybe_value = just(42)
      assert guard(maybe_value, false) == nothing()
    end

    test "returns Nothing when given Nothing" do
      nothing_value = nothing()
      assert guard(nothing_value, true) == nothing_value
    end
  end

  describe "filter/2" do
    test "returns Just value when predicate is true" do
      maybe_value = just(42)
      assert filter(maybe_value, &(&1 > 40)) == maybe_value
    end

    test "returns Nothing when predicate is false" do
      maybe_value = just(42)
      assert filter(maybe_value, &(&1 > 50)) == nothing()
    end

    test "returns Nothing when given Nothing" do
      nothing_value = nothing()
      assert filter(nothing_value, fn _ -> true end) == nothing_value
    end
  end

  describe "traverse/2" do
    test "applies a function and sequences the results" do
      result = traverse([1, 2, 3], &just/1)
      assert result == just([1, 2, 3])
    end

    test "empty returns just an empty list" do
      result = traverse([], &just/1)
      assert result == just([])
    end

    test "returns Nothing if the function returns Nothing for any element" do
      result =
        traverse(
          [1, 2, 3],
          fn x ->
            if x > 1,
              do: nothing(),
              else: just(x)
          end
        )

      assert result == nothing()
    end
  end

  describe "sequence/1" do
    test "sequences a list of Just values" do
      result = sequence([just(1), just(2), just(3)])
      assert result == just([1, 2, 3])
    end

    test "returns Nothing if any value is Nothing" do
      result = sequence([just(1), nothing(), just(3)])
      assert result == nothing()
    end
  end

  describe "concat/1" do
    test "returns an empty list when given an empty list" do
      assert concat([]) == []
    end

    test "filters out Nothing and unwraps Just values" do
      assert concat([just(1), nothing(), just(2)]) == [1, 2]
    end

    test "returns an empty list when all values are Nothing" do
      assert concat([nothing(), nothing()]) == []
    end

    test "handles a list with only Just values" do
      assert concat([just("a"), just("b"), just("c")]) == ["a", "b", "c"]
    end
  end

  describe "concat_map/2" do
    test "returns an empty list when given an empty list" do
      assert concat_map([], fn x -> x end) == []
    end

    test "applies the function and collects Just values" do
      fun = fn x -> if rem(x, 2) == 0, do: just(x), else: nothing() end
      assert concat_map([1, 2, 3, 4], fun) == [2, 4]
    end

    test "returns an empty list when the function always returns Nothing" do
      fun = fn _ -> nothing() end
      assert concat_map([1, 2, 3], fun) == []
    end

    test "handles all Just returns from the function" do
      fun = fn x -> just(x * 2) end
      assert concat_map([1, 2, 3], fun) == [2, 4, 6]
    end

    test "handles mixed Just and Nothing results" do
      fun = fn x -> if x > 0, do: just(x), else: nothing() end
      assert concat_map([-1, 0, 1, 2], fun) == [1, 2]
    end
  end

  # Ord and Eq Tests

  describe "Eq.eq?/2" do
    test "returns true for equal Just values" do
      assert Eq.eq?(just(1), just(1)) == true
    end

    test "returns false for different Just values" do
      assert Eq.eq?(just(1), just(2)) == false
    end

    test "returns true for two Nothing values" do
      assert Eq.eq?(nothing(), nothing()) == true
    end

    test "returns false for Just and Nothing comparison" do
      assert Eq.eq?(just(1), nothing()) == false
    end

    test "returns false for Nothing and Just comparison" do
      assert Eq.eq?(nothing(), just(1)) == false
    end
  end

  describe "Eq.not_eq?/2" do
    test "returns false for equal Just values" do
      assert Eq.not_eq?(just(1), just(1)) == false
    end

    test "returns true for different Just values" do
      assert Eq.not_eq?(just(1), just(2)) == true
    end

    test "returns false for two Nothing values" do
      assert Eq.not_eq?(nothing(), nothing()) == false
    end

    test "returns true for Just and Nothing comparison" do
      assert Eq.not_eq?(just(1), nothing()) == true
    end

    test "returns true for Nothing and Just comparison" do
      assert Eq.not_eq?(nothing(), just(1)) == true
    end
  end

  describe "lift_eq/1" do
    setup do
      number_eq = %{eq?: &Kernel.==/2}
      {:ok, eq: lift_eq(number_eq)}
    end

    test "returns true for equal Just values", %{eq: eq} do
      assert eq.eq?.(just(1), just(1)) == true
      assert eq.not_eq?.(just(1), just(1)) == false
    end

    test "returns false for different Just values", %{eq: eq} do
      assert eq.eq?.(just(1), just(2)) == false
      assert eq.not_eq?.(just(1), just(2)) == true
    end

    test "returns true for two Nothing values", %{eq: eq} do
      assert eq.eq?.(nothing(), nothing()) == true
      assert eq.not_eq?.(nothing(), nothing()) == false
    end

    test "returns false for Just and Nothing comparison", %{eq: eq} do
      assert eq.eq?.(just(1), nothing()) == false
      assert eq.not_eq?.(just(1), nothing()) == true
    end

    test "returns false for Nothing and Just comparison", %{eq: eq} do
      assert eq.eq?.(nothing(), just(1)) == false
      assert eq.not_eq?.(nothing(), just(1)) == true
    end
  end

  describe "Ord.lt?/2" do
    test "returns true for less Just value" do
      assert Ord.lt?(just(1), just(2)) == true
    end

    test "returns false for more Just value" do
      assert Ord.lt?(just(2), just(1)) == false
    end

    test "returns false for equal Just values" do
      assert Ord.lt?(just(1), just(1)) == false
    end

    test "returns true for Nothing compared to Just value" do
      assert Ord.lt?(nothing(), just(1)) == true
    end

    test "returns false for Just compared to Nothing value" do
      assert Ord.lt?(just(1), nothing()) == false
    end

    test "returns false for two Nothing values" do
      assert Ord.lt?(nothing(), nothing()) == false
    end
  end

  describe "Ord.le?/2" do
    test "returns true when Just value is less than or equal to another Just value" do
      assert Ord.le?(just(1), just(2)) == true
      assert Ord.le?(just(2), just(2)) == true
    end

    test "returns false when Just value is greater than another Just value" do
      assert Ord.le?(just(2), just(1)) == false
    end

    test "returns true for Nothing compared to Just" do
      assert Ord.le?(nothing(), just(1)) == true
    end

    test "returns true for Nothing compared to Nothing" do
      assert Ord.le?(nothing(), nothing()) == true
    end

    test "returns false for Just compared to Nothing" do
      assert Ord.le?(just(1), nothing()) == false
    end
  end

  describe "Ord.gt?/2" do
    test "returns true when Just value is greater than another Just value" do
      assert Ord.gt?(just(2), just(1)) == true
    end

    test "returns false when Just value is less than or equal to another Just value" do
      assert Ord.gt?(just(1), just(2)) == false
      assert Ord.gt?(just(2), just(2)) == false
    end

    test "returns false for Nothing compared to Just" do
      assert Ord.gt?(nothing(), just(1)) == false
    end

    test "returns false for Nothing compared to Nothing" do
      assert Ord.gt?(nothing(), nothing()) == false
    end

    test "returns true for Just compared to Nothing" do
      assert Ord.gt?(just(1), nothing()) == true
    end
  end

  describe "Ord.ge?/2" do
    test "returns true when Just value is greater than or equal to another Just value" do
      assert Ord.ge?(just(2), just(1)) == true
      assert Ord.ge?(just(2), just(2)) == true
    end

    test "returns false when Just value is less than another Just value" do
      assert Ord.ge?(just(1), just(2)) == false
    end

    test "returns true for Just compared to Nothing" do
      assert Ord.ge?(just(1), nothing()) == true
    end

    test "returns true for Nothing compared to Nothing" do
      assert Ord.ge?(nothing(), nothing()) == true
    end

    test "returns false for Nothing compared to Just" do
      assert Ord.ge?(nothing(), just(1)) == false
    end
  end

  describe "lift_ord/1" do
    setup do
      number_ord = %{lt?: &Kernel.</2}
      {:ok, ord: lift_ord(number_ord)}
    end

    test "Nothing is less than any Just", %{ord: ord} do
      assert ord.lt?.(nothing(), just(42)) == true
    end

    test "Just is greater than Nothing", %{ord: ord} do
      assert ord.gt?.(just(42), nothing()) == true
    end

    test "A Just value is not less than Nothing", %{ord: ord} do
      assert ord.lt?.(just(42), nothing()) == false
    end

    test "Orders Just values based on their contained values", %{ord: ord} do
      assert ord.lt?.(just(42), just(43)) == true
      assert ord.gt?.(just(43), just(42)) == true
      assert ord.le?.(just(42), just(42)) == true
      assert ord.ge?.(just(42), just(42)) == true
    end

    test "Nothing is equal to Nothing in terms of ordering", %{ord: ord} do
      assert ord.le?.(nothing(), nothing()) == true
      assert ord.ge?.(nothing(), nothing()) == true
    end
  end

  describe "lift_identity/1" do
    test "converts Identity with a value to Just" do
      result = Identity.pure(42) |> lift_identity()
      assert result == just(42)
    end

    test "converts Identity with nil to Nothing" do
      result = Identity.pure(nil) |> lift_identity()
      assert result == nothing()
    end
  end

  describe "lift_either/1" do
    test "converts Right to Just" do
      result = Either.right(42) |> lift_either()
      assert result == just(42)
    end

    test "converts Left to Nothing" do
      result = Either.left("Error") |> lift_either()
      assert result == nothing()
    end
  end

  describe "lift_predicate/2" do
    test "returns Just when the predicate is true" do
      pred = fn x -> x > 0 end

      result =
        5
        |> lift_predicate(pred)

      assert result == just(5)
    end

    test "returns Nothing when the predicate is false" do
      pred = fn x -> x > 0 end

      result =
        0
        |> lift_predicate(pred)

      assert result == nothing()
    end
  end

  describe "to_predicate/1" do
    test "returns true for Just values" do
      assert to_predicate(just(42)) == true
      assert to_predicate(just("hello")) == true
      assert to_predicate(just(%{key: "value"})) == true
    end

    test "returns false for Nothing" do
      assert to_predicate(nothing()) == false
    end

    test "works in Enum.filter/2 to keep Just values" do
      list = [just(1), nothing(), just(3), nothing(), just(5)]

      result = Enum.filter(list, &to_predicate/1)

      assert result == [just(1), just(3), just(5)]
    end

    test "filters out Nothing values when used in a pipeline" do
      result =
        [just("a"), nothing(), just("b")]
        |> Enum.filter(&to_predicate/1)
        |> Enum.map(fn %Just{value: v} -> v end)

      assert result == ["a", "b"]
    end
  end

  describe "from_nil/1" do
    test "converts nil to Nothing" do
      assert from_nil(nil) == %Nothing{}
    end

    test "converts non-nil value to Just" do
      assert from_nil(42) == %Just{value: 42}
    end

    test "converts non-nil value (string) to Just" do
      assert from_nil("hello") == %Just{value: "hello"}
    end
  end

  describe "to_nil/1" do
    test "converts Just to the contained value" do
      assert to_nil(%Just{value: 42}) == 42
    end

    test "converts Nothing to nil" do
      assert to_nil(%Nothing{}) == nil
    end

    test "converts Just (string) to the contained string value" do
      assert to_nil(%Just{value: "hello"}) == "hello"
    end
  end

  describe "from_try/1" do
    test "returns Just when the function executes successfully" do
      result = from_try(fn -> 5 end)
      assert result == just(5)
    end

    test "returns Just when the function returns a complex value" do
      complex_value = %{name: "Alice", age: 30}
      result = from_try(fn -> complex_value end)
      assert result == just(complex_value)
    end

    test "returns Nothing when the function raises an exception" do
      result = from_try(fn -> raise "error" end)
      assert result == nothing()
    end

    test "returns Nothing when the function raises a different exception" do
      result = from_try(fn -> :erlang.error(:badarith) end)
      assert result == nothing()
    end
  end

  describe "to_try!/2" do
    test "returns value from Maybe.Just" do
      assert to_try!(%Just{value: 42}) == 42
    end

    test "raises an error for Maybe.Nothing with default message" do
      assert_raise RuntimeError, "Nothing value encountered", fn ->
        to_try!(%Nothing{})
      end
    end

    test "raises an error for Maybe.Nothing with custom message" do
      assert_raise RuntimeError, "Custom error message", fn ->
        to_try!(%Nothing{}, "Custom error message")
      end
    end
  end

  describe "from_result/1" do
    test "converts {:ok, value} to Maybe.Just" do
      assert from_result({:ok, 42}) == %Just{value: 42}
    end

    test "converts {:error, reason} to Maybe.Nothing" do
      assert from_result({:error, "some error"}) == %Nothing{}
    end
  end

  describe "to_result/1" do
    test "converts Maybe.Just to {:ok, value}" do
      assert to_result(%Just{value: 42}) == {:ok, 42}
    end

    test "converts Maybe.Nothing to {:error, :nothing}" do
      assert to_result(%Nothing{}) == {:error, :nothing}
    end
  end

  describe "or_else/2" do
    test "returns the first Just value without calling the fallback" do
      assert or_else(just(42), fn -> just(100) end) == just(42)
    end

    test "calls the fallback function when given Nothing" do
      assert or_else(nothing(), fn -> just(100) end) == just(100)
    end

    test "returns Nothing if both the original and fallback are Nothing" do
      assert or_else(nothing(), fn -> nothing() end) == nothing()
    end

    test "fallback function is not called when the first Maybe is Just" do
      refute_receive {:fallback_called}

      result =
        or_else(just(42), fn ->
          send(self(), {:fallback_called})
          just(100)
        end)

      assert result == just(42)
    end
  end
end
