defmodule Funx.Monad.EitherTest do
  @moduledoc false

  use ExUnit.Case, async: true

  doctest Funx.Monad.Either
  doctest Funx.Monad.Either.Left
  doctest Funx.Monad.Either.Right

  import Funx.Monad.Either
  import Funx.Foldable, only: [fold_l: 3, fold_r: 3]
  import Funx.Monad.Maybe, only: [just: 1, nothing: 0]
  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Summarizable, only: [summarize: 1]

  alias Funx.{Eq, Ord}
  alias Funx.Monad.{Either, Maybe}
  alias Either.{Left, Right}

  describe "pure/1" do
    test "wraps a value in a Right monad" do
      assert %Right{right: 42} = pure(42)
    end
  end

  describe "right/1" do
    test "wraps a value in a Right monad" do
      assert %Right{right: 42} = right(42)
    end
  end

  describe "left/1" do
    test "wraps an error value in a Left monad" do
      assert %Left{left: "error"} = left("error")
    end
  end

  describe "summarize/1" do
    test "summarizes a string inside Left" do
      assert summarize(left("error")) == {:either_left, {:string, "error"}}
    end

    test "summarizes a list inside Left" do
      assert summarize(left([1, 2, 3])) ==
               {:either_left, {:list, [integer: 1, integer: 2, integer: 3]}}
    end

    test "summarizes a nested Left" do
      inner = left(:oops)
      outer = left(inner)
      assert summarize(outer) == {:either_left, {:either_left, {:atom, :oops}}}
    end

    test "summarizes an integer inside Right" do
      assert summarize(right(42)) == {:either_right, {:integer, 42}}
    end

    test "summarizes a string inside Right" do
      assert summarize(right("hello")) == {:either_right, {:string, "hello"}}
    end

    test "summarizes a list inside Right" do
      assert summarize(right([1, 2, 3])) ==
               {:either_right, {:list, [integer: 1, integer: 2, integer: 3]}}
    end

    test "summarizes a nested Right" do
      inner = right(:ok)
      outer = right(inner)
      assert summarize(outer) == {:either_right, {:either_right, {:atom, :ok}}}
    end
  end

  describe "map/2" do
    test "applies a function to the value inside a Right monad" do
      assert %Right{right: 43} =
               right(42)
               |> map(&(&1 + 1))
    end

    test "returns Left when mapping over a Left monad" do
      assert %Left{} =
               left("error")
               |> map(&(&1 + 1))
    end
  end

  describe "bind/2" do
    test "applies a function returning a monad to the value inside a Right monad" do
      assert %Right{right: 21} =
               right(42)
               |> bind(fn x -> right(div(x, 2)) end)
    end

    test "returns Left when binding over a Left monad" do
      assert %Left{left: "error"} =
               left("error")
               |> bind(fn _ -> right(10) end)
    end

    test "returns Left when the function returns Left" do
      assert %Left{left: "error"} =
               right(42)
               |> bind(fn _ -> left("error") end)
    end
  end

  describe "ap/2" do
    test "applies a function in Right to a value in Right" do
      assert ap(right(&(&1 + 1)), right(42)) == right(43)
    end

    test "returns Left if the function is in Left" do
      assert ap(left("error"), right(42)) == left("error")
    end

    test "returns Left if the value is in Left" do
      assert ap(right(&(&1 + 1)), left("error")) == left("error")
    end

    test "returns Left if both are Left" do
      assert ap(left("error"), left("error")) == left("error")
    end
  end

  describe "fold_r/3" do
    test "applies the right_func to a Right value" do
      result =
        right(42)
        |> fold_r(fn x -> "Right #{x}" end, fn -> "Left" end)

      assert result == "Right 42"
    end

    test "applies the left_func to a Left value" do
      result =
        left("error")
        |> fold_r(fn x -> "Right #{x}" end, fn value -> "Left: #{value}" end)

      assert result == "Left: error"
    end
  end

  describe "fold_l/3" do
    test "applies the right_func to a Right value" do
      result =
        right(42)
        |> fold_l(fn x -> "Right #{x}" end, fn -> "Left" end)

      assert result == "Right 42"
    end

    test "applies the left_func to a Left value" do
      result =
        left("error")
        |> fold_l(fn x -> "Right #{x}" end, fn value -> "Left: #{value}" end)

      assert result == "Left: error"
    end
  end

  describe "right?/1" do
    test "returns true for Right values" do
      assert right?(right(42)) == true
    end

    test "returns false for Left values" do
      assert right?(left("error")) == false
    end
  end

  describe "left?/1" do
    test "returns true for Left values" do
      assert left?(left("error")) == true
    end

    test "returns false for Right values" do
      assert left?(right(42)) == false
    end
  end

  describe "String.Chars" do
    test "Right value string representation" do
      right_value = right(42)
      assert to_string(right_value) == "Right(42)"
    end

    test "Left value string representation" do
      left_value = left("error")
      assert to_string(left_value) == "Left(error)"
    end
  end

  describe "map_left/2" do
    test "transforms a Left value" do
      result = map_left(left("error"), fn e -> "wrapped: " <> e end)
      assert result == left("wrapped: error")
    end

    test "leaves a Right value unchanged" do
      result = map_left(right(42), fn _ -> "should not be called" end)
      assert result == right(42)
    end

    test "can transform complex Left values" do
      result = map_left(left(%{code: 400}), fn err -> Map.put(err, :handled, true) end)
      assert result == left(%{code: 400, handled: true})
    end

    test "does not call the function for Right" do
      refute_receive {:called}

      result =
        map_left(right(:ok), fn _ ->
          send(self(), {:called})
          :fail
        end)

      assert result == right(:ok)
    end
  end

  describe "filter_or_else/3" do
    test "returns Right value when predicate is true" do
      either_value = right(1)
      assert filter_or_else(either_value, &(&1 > 0), fn -> "error" end) == either_value
    end

    test "returns Left value when predicate is false" do
      either_value = right(-1)

      assert filter_or_else(either_value, &(&1 > 0), fn -> "error" end) ==
               left("error")
    end

    test "returns Left unchanged when already a Left" do
      left_value = left("existing error")

      assert filter_or_else(left_value, fn _ -> true end, fn -> "new error" end) ==
               left_value
    end
  end

  describe "get_or_else/2" do
    test "returns the value in Right when present" do
      assert get_or_else(right(42), 0) == 42
    end

    test "returns the default value when Left" do
      assert get_or_else(left("error"), 0) == 0
    end
  end

  describe "or_else/2" do
    test "returns the first Right value without calling the fallback" do
      assert or_else(right(42), fn -> right(100) end) == right(42)
    end

    test "calls the fallback function when given Left" do
      assert or_else(left(:error), fn -> right(100) end) == right(100)
    end

    test "returns Left if both the original and fallback are Left" do
      assert or_else(left(:error), fn -> left(:fallback_error) end) == left(:fallback_error)
    end

    test "fallback function is not called when the first Either is Right" do
      refute_receive {:fallback_called}

      result =
        or_else(right(42), fn ->
          send(self(), {:fallback_called})
          right(100)
        end)

      assert result == right(42)
    end
  end

  describe "flip/1" do
    test "converts Left to Right" do
      assert flip(left(:error)) == right(:error)
    end

    test "converts Right to Left" do
      assert flip(right(42)) == left(42)
    end

    test "flip twice returns original" do
      assert flip(flip(left(:error))) == left(:error)
      assert flip(flip(right(42))) == right(42)
    end
  end

  describe "concat/1" do
    test "returns an empty list when given an empty list" do
      assert concat([]) == []
    end

    test "filters out Left and unwraps Right values" do
      assert concat([right(1), left(:error), right(2)]) == [1, 2]
    end

    test "returns an empty list when all values are Left" do
      assert concat([left(:a), left(:b)]) == []
    end

    test "handles a list with only Right values" do
      assert concat([right("a"), right("b"), right("c")]) == ["a", "b", "c"]
    end
  end

  describe "traverse/2" do
    test "empty returns a right empty list" do
      result = traverse([], &right/1)
      assert result == right([])
    end

    test "applies a function and sequences the results" do
      result = traverse([1, 2, 3], &right/1)
      assert result == right([1, 2, 3])
    end

    test "returns Left if the function returns Left for any element" do
      result =
        traverse(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 1), fn v -> "#{v} is not valid" end)
          end
        )

      assert result == left("2 is not valid")
    end
  end

  describe "traverse_a/2" do
    test "empty returns a right empty list" do
      result = traverse_a([], &right/1)
      assert result == right([])
    end

    test "applies a function and accumulates Right results" do
      result = traverse_a([1, 2, 3], &right/1)
      assert result == right([1, 2, 3])
    end

    test "returns Left with all errors if function fails on multiple elements" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 1), fn v -> "bad: #{v}" end)
          end
        )

      assert result == left(["bad: 2", "bad: 3"])
    end

    test "returns Left with one error if only one element fails" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 2), fn v -> "bad: #{v}" end)
          end
        )

      assert result == left(["bad: 3"])
    end

    test "preserves earlier Left even if later elements are Right" do
      result =
        traverse_a(
          [1, 2, 3],
          fn
            1 -> left("fail 1")
            2 -> right("ok 2")
            3 -> right("ok 3")
          end
        )

      assert result == left(["fail 1"])
    end

    test "does not nest error lists inside Left" do
      result =
        traverse_a(
          [2, 3],
          fn x -> left(["bad: #{x}"]) end
        )

      assert result == left(["bad: 2", "bad: 3"])
    end
  end

  describe "traverse_a/2 with ValidationError aggregation" do
    alias Funx.Errors.ValidationError
    alias Funx.Monad.Either

    defp fail_if_odd(x) do
      if rem(x, 2) == 0 do
        Either.right(x)
      else
        Either.left(ValidationError.new("not even: #{x}"))
      end
    end

    test "returns Right when all elements pass" do
      result = traverse_a([2, 4, 6], &fail_if_odd/1)
      assert result == Either.right([2, 4, 6])
    end

    test "returns a ValidationError when one element fails" do
      result = traverse_a([2, 3, 4], &fail_if_odd/1)

      assert result ==
               Either.left(%ValidationError{
                 errors: ["not even: 3"]
               })
    end

    test "returns a merged ValidationError when multiple elements fail" do
      result = traverse_a([1, 2, 3, 4, 5], &fail_if_odd/1)

      assert result ==
               Either.left(%ValidationError{
                 errors: ["not even: 1", "not even: 3", "not even: 5"]
               })
    end

    test "does not wrap ValidationError again if already wrapped" do
      result =
        traverse_a(
          [1, 2],
          fn
            1 -> Either.left(ValidationError.new(["pre_wrapped 1"]))
            2 -> Either.left(ValidationError.new("from 2"))
          end
        )

      assert result ==
               Either.left(%ValidationError{
                 errors: ["pre_wrapped 1", "from 2"]
               })
    end

    test "preserves error order from left to right" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x -> Either.left(ValidationError.new("fail: #{x}")) end
        )

      assert result ==
               Either.left(%ValidationError{
                 errors: ["fail: 1", "fail: 2", "fail: 3"]
               })
    end
  end

  describe "wither_a/2" do
    test "empty returns a right empty list" do
      result = wither_a([], fn _ -> right(just(:ok)) end)
      assert result == right([])
    end

    test "filters out Nothing and keeps Just values" do
      result =
        wither_a(
          [1, 2, 3],
          fn
            2 -> right(nothing())
            x -> right(just(x * 10))
          end
        )

      assert result == right([10, 30])
    end

    test "returns Left if function returns Left for any element" do
      result =
        wither_a(
          [1, 2, 3],
          fn
            2 -> left("bad 2")
            x -> right(just(x * 10))
          end
        )

      assert result == left(["bad 2"])
    end

    test "accumulates multiple Left errors" do
      result =
        wither_a(
          [1, 2, 3],
          fn
            x when x < 3 -> left(["fail #{x}"])
            x -> right(just(x))
          end
        )

      assert result == left(["fail 1", "fail 2"])
    end

    test "returns Right([]) if all results are Right(Nothing)" do
      result =
        wither_a(
          [1, 2, 3],
          fn _ -> right(nothing()) end
        )

      assert result == right([])
    end

    test "does not nest error lists inside Left" do
      result =
        wither_a(
          [2, 3],
          fn x -> left(["bad: #{x}"]) end
        )

      assert result == left(["bad: 2", "bad: 3"])
    end
  end

  describe "concat_map/2" do
    test "returns an empty list when given an empty list" do
      assert concat_map([], fn x -> x end) == []
    end

    test "applies the function and collects Right values" do
      fun = fn x -> if rem(x, 2) == 0, do: right(x), else: left(:odd) end
      assert concat_map([1, 2, 3, 4], fun) == [2, 4]
    end

    test "returns an empty list when the function always returns Left" do
      fun = fn _ -> left(:fail) end
      assert concat_map([1, 2, 3], fun) == []
    end

    test "handles all Right returns from the function" do
      fun = fn x -> right(x * 2) end
      assert concat_map([1, 2, 3], fun) == [2, 4, 6]
    end

    test "handles mixed Right and Left results" do
      fun = fn x -> if x > 0, do: right(x), else: left(:non_positive) end
      assert concat_map([-1, 0, 1, 2], fun) == [1, 2]
    end
  end

  describe "sequence/1" do
    test "sequences a list of Right values" do
      result = sequence([right(1), right(2), right(3)])
      assert result == right([1, 2, 3])
    end

    test "returns Left if any value is Left" do
      result = sequence([right(1), left("error"), right(3)])
      assert result == left("error")
    end
  end

  describe "sequence_a/1" do
    test "returns Right([]) for an empty list" do
      assert sequence_a([]) == right([])
    end

    test "returns Right when all elements are Right" do
      assert sequence_a([right(1), right(2), right(3)]) ==
               right([1, 2, 3])
    end

    test "returns Left with a non-empty list of errors when encountering Lefts" do
      assert sequence_a([right(1), left("Error 1"), right(2), left("Error 2")]) ==
               left(["Error 1", "Error 2"])
    end

    test "returns Left even when followed by a Right" do
      assert sequence_a([left("Error 1"), left("Error 2"), right(3)]) ==
               left(["Error 1", "Error 2"])
    end

    test "returns Left if all elements are Left, collecting all errors" do
      assert sequence_a([left("Error 1"), left("Error 2"), left("Error 3")]) ==
               left(["Error 1", "Error 2", "Error 3"])
    end

    test "returns Right when all elements are Right, including complex values" do
      assert sequence_a([right(1), right(2), right([])]) ==
               right([1, 2, []])
    end
  end

  describe "validate/2" do
    def positive?(x), do: x > 0
    def even?(x), do: rem(x, 2) == 0

    def validate_positive(x) do
      lift_predicate(x, &positive?/1, fn v -> "Value must be positive: #{v}" end)
    end

    def validate_even(x) do
      lift_predicate(x, &even?/1, fn v -> "Value must be even: #{v}" end)
    end

    test "returns Right for a single validation when it passes" do
      assert validate(5, &validate_positive/1) == right(5)
    end

    test "returns Left for a single validation when it fails" do
      assert validate(-5, &validate_positive/1) ==
               left(["Value must be positive: -5"])
    end

    test "returns Left for a single validation with a different condition" do
      assert validate(3, &validate_even/1) ==
               left(["Value must be even: 3"])
    end

    test "returns Right for a single validation with a different condition" do
      assert validate(2, &validate_even/1) == right(2)
    end

    test "returns Right when all validators pass" do
      validators = [&validate_positive/1, &validate_even/1]
      assert validate(4, validators) == right(4)
    end

    test "returns Left with a single error when one validator fails" do
      validators = [&validate_positive/1, &validate_even/1]
      assert validate(3, validators) == left(["Value must be even: 3"])
    end

    test "returns Left with multiple errors when multiple validators fail" do
      validators = [&validate_positive/1, &validate_even/1]

      assert validate(-3, validators) ==
               left(["Value must be positive: -3", "Value must be even: -3"])
    end

    test "returns Right when all validators pass with different value" do
      validators = [&validate_positive/1]
      assert validate(1, validators) == right(1)
    end

    test "returns Left when all validators fail" do
      validators = [&validate_positive/1, &validate_even/1]
      assert validate(-2, validators) == left(["Value must be positive: -2"])
    end
  end

  describe "Eq.eq?/2" do
    test "returns true for equal Right values" do
      assert Eq.eq?(right(1), right(1)) == true
    end

    test "returns false for different Right values" do
      assert Eq.eq?(right(1), right(2)) == false
    end

    test "returns true for two Left values" do
      assert Eq.eq?(left(1), left(1)) == true
    end

    test "returns false for Right and Left comparison" do
      assert Eq.eq?(right(1), left(1)) == false
    end

    test "returns false for Left and Right comparison" do
      assert Eq.eq?(left(1), right(1)) == false
    end
  end

  describe "Eq.not_eq?/2" do
    test "returns false for equal Right values" do
      assert Eq.not_eq?(right(1), right(1)) == false
    end

    test "returns true for different Right values" do
      assert Eq.not_eq?(right(1), right(2)) == true
    end

    test "returns false for two equal Left values" do
      assert Eq.not_eq?(left(1), left(1)) == false
    end

    test "returns true for Right and Left comparison" do
      assert Eq.not_eq?(right(1), left(1)) == true
    end

    test "returns true for Left and Right comparison" do
      assert Eq.not_eq?(left(1), right(1)) == true
    end
  end

  describe "lift_eq/1" do
    setup do
      number_eq = %{
        eq?: &Kernel.==/2,
        not_eq?: &Kernel.!=/2
      }

      {:ok, eq: lift_eq(number_eq)}
    end

    test "returns true for equal Right values", %{eq: eq} do
      assert eq.eq?.(right(1), right(1)) == true
      assert eq.not_eq?.(right(1), right(1)) == false
    end

    test "returns false for different Right values", %{eq: eq} do
      assert eq.eq?.(right(1), right(2)) == false
      assert eq.not_eq?.(right(1), right(2)) == true
    end

    test "returns true for two Left values", %{eq: eq} do
      assert eq.eq?.(left(1), left(1)) == true
      assert eq.not_eq?.(left(1), left(1)) == false
    end

    test "returns false for Right and Left comparison", %{eq: eq} do
      assert eq.eq?.(right(1), left(1)) == false
      assert eq.not_eq?.(right(1), left(1)) == true
    end

    test "returns false for Left and Right comparison", %{eq: eq} do
      assert eq.eq?.(left(1), right(1)) == false
      assert eq.not_eq?.(left(1), right(1)) == true
    end
  end

  describe "Ord.lt?/2" do
    test "returns true when Right value is less than another Right value" do
      assert Ord.lt?(right(1), right(2)) == true
    end

    test "returns false when Right value is greater than another Right value" do
      assert Ord.lt?(right(2), right(1)) == false
    end

    test "returns false when Right values are equal" do
      assert Ord.lt?(right(2), right(2)) == false
    end

    test "returns true for Left compared to Right" do
      assert Ord.lt?(left(1), right(1)) == true
    end

    test "returns true for Left value less than another Left value" do
      assert Ord.lt?(left(1), left(2)) == true
    end

    test "returns false for Left value greater than another Left value" do
      assert Ord.lt?(left(2), left(1)) == false
    end

    test "returns false for Left values that are equal" do
      assert Ord.lt?(left(2), left(2)) == false
    end

    test "returns false for Right compared to Left" do
      assert Ord.lt?(right(1), left(1)) == false
    end
  end

  describe "Ord.le?/2" do
    test "returns true when Right value is less than or equal to another Right value" do
      assert Ord.le?(right(1), right(2)) == true
      assert Ord.le?(right(2), right(2)) == true
    end

    test "returns false when Right value is greater than another Right value" do
      assert Ord.le?(right(2), right(1)) == false
    end

    test "returns true for Left compared to Right" do
      assert Ord.le?(left(100), right(1)) == true
    end

    test "returns true when Left value is less than or equal to another Left value" do
      assert Ord.le?(left(1), left(2)) == true
      assert Ord.le?(left(2), left(2)) == true
    end

    test "returns false when Left value is greater than another Left value" do
      assert Ord.le?(left(2), left(1)) == false
    end

    test "returns false for Right compared to Left" do
      assert Ord.le?(right(1), left(100)) == false
    end
  end

  describe "Ord.gt?/2" do
    test "returns true when Right value is greater than another Right value" do
      assert Ord.gt?(right(2), right(1)) == true
    end

    test "returns false when Right value is less than or equal to another Right value" do
      assert Ord.gt?(right(1), right(2)) == false
      assert Ord.gt?(right(2), right(2)) == false
    end

    test "returns false for Left compared to Right" do
      assert Ord.gt?(left(100), right(1)) == false
    end

    test "returns true when Left value is greater than another Left value" do
      assert Ord.gt?(left(2), left(1)) == true
    end

    test "returns false when Left value is less than or equal to another Left value" do
      assert Ord.gt?(left(1), left(2)) == false
      assert Ord.gt?(left(2), left(2)) == false
    end

    test "returns true for Right compared to Left" do
      assert Ord.gt?(right(1), left(100)) == true
    end
  end

  describe "Ord.ge?/2" do
    test "returns true when Right value is greater than or equal to another Right value" do
      assert Ord.ge?(right(2), right(1)) == true
      assert Ord.ge?(right(2), right(2)) == true
    end

    test "returns false when Right value is less than another Right value" do
      assert Ord.ge?(right(1), right(2)) == false
    end

    test "returns true for Right compared to Left" do
      assert Ord.ge?(right(1), left(1)) == true
    end

    test "returns true when Left value is greater than or equal to another Left value" do
      assert Ord.ge?(left(2), left(1)) == true
      assert Ord.ge?(left(2), left(2)) == true
    end

    test "returns false when Left value is less than another Left value" do
      assert Ord.ge?(left(1), left(2)) == false
    end

    test "returns false for Left compared to Right" do
      assert Ord.ge?(left(1), right(1)) == false
    end
  end

  describe "lift_ord/1" do
    setup do
      number_ord = %{
        lt?: &</2,
        le?: &<=/2,
        gt?: &>/2,
        ge?: &>=/2
      }

      {:ok, ord: lift_ord(number_ord)}
    end

    test "Left is less than any Right, but not less than another Left by default", %{ord: ord} do
      assert ord.lt?.(left(100), right(1)) == true
      assert ord.lt?.(right(1), left(100)) == false
      assert ord.lt?.(left(100), left(100)) == false
    end

    test "Right is greater than Left, Left is not greater than Right or itself", %{ord: ord} do
      assert ord.gt?.(right(1), left(100)) == true
      assert ord.gt?.(left(100), right(1)) == false
      assert ord.gt?.(left(1), left(1)) == false
    end

    test "Right is not less than Left", %{ord: ord} do
      assert ord.lt?.(right(1), left(1)) == false
    end

    test "Orders Right values based on their contained values", %{ord: ord} do
      assert ord.lt?.(right(42), right(43)) == true
      assert ord.gt?.(right(43), right(42)) == true
      assert ord.le?.(right(42), right(42)) == true
      assert ord.ge?.(right(42), right(42)) == true
    end

    test "Orders Left values based on their contained values", %{ord: ord} do
      assert ord.lt?.(left(1), left(2)) == true
      assert ord.gt?.(left(2), left(1)) == true
      assert ord.le?.(left(1), left(2)) == true
      assert ord.ge?.(left(2), left(1)) == true
      assert ord.le?.(left(1), left(1)) == true
      assert ord.ge?.(left(1), left(1)) == true
    end

    test "le? and ge? for Left vs Right and vice versa", %{ord: ord} do
      assert ord.le?.(left(1), right(1)) == true
      assert ord.ge?.(right(1), left(1)) == true
      assert ord.le?.(right(1), left(1)) == false
      assert ord.ge?.(left(1), right(1)) == false
    end
  end

  describe "lift_maybe/2" do
    test "returns Right when the function returns Just" do
      result =
        Maybe.just(5)
        |> lift_maybe(fn -> "Missing value" end)

      assert result == right(5)
    end

    test "returns Left when the function returns Nothing" do
      result =
        Maybe.nothing()
        |> lift_maybe(fn -> "Missing value" end)

      assert result == left("Missing value")
    end
  end

  describe "lift_predicate/3" do
    test "returns Right when the predicate is true" do
      pred = fn x -> x > 0 end
      false_func = fn _x -> "Predicate failed" end

      result =
        5
        |> lift_predicate(pred, false_func)

      assert result == right(5)
    end

    test "returns Left when the predicate is false" do
      pred = fn x -> x > 0 end
      false_func = fn x -> "#{x} failed the check" end

      result =
        0
        |> lift_predicate(pred, false_func)

      assert result == left("0 failed the check")
    end
  end

  describe "from_result/1" do
    test "converts {:ok, value} to Right" do
      result = from_result({:ok, 42})
      assert result == right(42)
    end

    test "converts {:error, reason} to Left" do
      result = from_result({:error, "error"})
      assert result == left("error")
    end
  end

  describe "to_result/1" do
    test "converts Right to {:ok, value}" do
      result = right(42)
      assert to_result(result) == {:ok, 42}
    end

    test "converts Left to {:error, reason}" do
      error = left("error")
      assert to_result(error) == {:error, "error"}
    end
  end

  describe "from_try/1" do
    test "converts a successful function into Right" do
      result = from_try(fn -> 42 end)

      assert result == %Right{right: 42}
    end

    test "converts a raised exception into Left" do
      result = from_try(fn -> raise "error" end)

      assert result == %Left{left: %RuntimeError{message: "error"}}
    end
  end

  describe "to_try!/1" do
    test "returns value from Right" do
      right_result = %Right{right: 42}

      assert to_try!(right_result) == 42
    end

    test "raises RuntimeError for Left with string reason" do
      left_result = %Left{left: "something went wrong"}

      assert_raise RuntimeError, "something went wrong", fn ->
        to_try!(left_result)
      end
    end

    test "raises RuntimeError for Left with list of errors" do
      left_result = %Left{left: ["error 1", "error 2"]}

      assert_raise RuntimeError, "error 1, error 2", fn ->
        to_try!(left_result)
      end
    end

    test "raises original exception if reason is an exception struct" do
      exception = %ArgumentError{message: "invalid argument"}
      left_result = %Left{left: exception}

      assert_raise ArgumentError, "invalid argument", fn ->
        to_try!(left_result)
      end
    end

    test "raises RuntimeError with inspected value for unexpected reason type" do
      left_result = %Left{left: {:unexpected, 123}}

      assert_raise RuntimeError, "Unexpected error: {:unexpected, 123}", fn ->
        to_try!(left_result)
      end
    end
  end
end
