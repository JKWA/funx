defmodule Monex.EitherTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]
  import Monex.Eq, only: [get_eq: 1]

  import Monex.Foldable, only: [fold_r: 3]
  import Monex.Either

  alias Monex.{Eq, Maybe, Ord}
  alias Monex.Either.{Left, Right}

  describe "pure/1" do
    test "wraps a value in a Right monad" do
      assert %Right{value: 42} = pure(42)
    end
  end

  describe "right/1" do
    test "wraps a value in a Right monad" do
      assert %Right{value: 42} = right(42)
    end
  end

  describe "left/1" do
    test "wraps an error value in a Left monad" do
      assert %Left{value: "error"} = left("error")
    end
  end

  describe "map/2" do
    test "applies a function to the value inside a Right monad" do
      assert %Right{value: 43} =
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
      assert %Right{value: 21} =
               right(42)
               |> bind(fn x -> right(div(x, 2)) end)
    end

    test "returns Left when binding over a Left monad" do
      assert %Left{value: "error"} =
               left("error")
               |> bind(fn _ -> right(10) end)
    end

    test "returns Left when the function returns Left" do
      assert %Left{value: "error"} =
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

  describe "traverse/2" do
    test "applies a function and sequences the results" do
      result = traverse(&right/1, [1, 2, 3])
      assert result == right([1, 2, 3])
    end

    test "returns Left if the function returns Left for any element" do
      result =
        traverse(
          fn x ->
            lift_predicate(x, &(&1 <= 1), fn -> "error" end)
          end,
          [1, 2, 3]
        )

      assert result == left("error")
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
      x |> lift_predicate(&positive?/1, fn -> "Value must be positive" end)
    end

    def validate_even(x) do
      x |> lift_predicate(&even?/1, fn -> "Value must be even" end)
    end

    test "returns Right for a single validation when it passes" do
      assert validate(5, &validate_positive/1) == right(5)
    end

    test "returns Left for a single validation when it fails" do
      assert validate(-5, &validate_positive/1) == left(["Value must be positive"])
    end

    test "returns Left for a single validation with a different condition" do
      assert validate(3, &validate_even/1) == left(["Value must be even"])
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
      assert validate(3, validators) == left(["Value must be even"])
    end

    test "returns Left with multiple errors when multiple validators fail" do
      validators = [&validate_positive/1, &validate_even/1]

      assert validate(-3, validators) ==
               left(["Value must be positive", "Value must be even"])
    end

    test "returns Right when all validators pass with different value" do
      validators = [&validate_positive/1]
      assert validate(1, validators) == right(1)
    end

    test "returns Left when all validators fail" do
      validators = [&validate_positive/1, &validate_even/1]
      assert validate(-2, validators) == left(["Value must be positive"])
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

  describe "get_eq/1" do
    setup do
      number_eq = %{eq?: &Kernel.==/2}
      {:ok, eq: get_eq(number_eq)}
    end

    test "returns true for equal Right values", %{eq: eq} do
      assert eq.eq?.(right(1), right(1)) == true
    end

    test "returns false for different Right values", %{eq: eq} do
      assert eq.eq?.(right(1), right(2)) == false
    end

    test "returns true for two Left values", %{eq: eq} do
      assert eq.eq?.(left(1), left(1)) == true
    end

    test "returns false for Right and Left comparison", %{eq: eq} do
      assert eq.eq?.(right(1), left(1)) == false
    end

    test "returns false for Left and Right comparison", %{eq: eq} do
      assert eq.eq?.(left(1), right(1)) == false
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

    test "returns true for Left compared to Left" do
      assert Ord.le?(left(1), left(2)) == true
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

    test "returns true for Left compared to Left" do
      assert Ord.ge?(left(1), left(1)) == true
    end

    test "returns false for Left compared to Right" do
      assert Ord.ge?(left(1), right(1)) == false
    end
  end

  describe "get_ord/1" do
    setup do
      number_ord = %{lt?: &Kernel.</2}
      {:ok, ord: get_ord(number_ord)}
    end

    test "Left is less than any Right", %{ord: ord} do
      assert ord[:lt?].(left(100), right(1)) == true
    end

    test "Right is greater than Left", %{ord: ord} do
      assert ord[:gt?].(right(1), left(100)) == true
    end

    test "Orders Right values based on their contained values", %{ord: ord} do
      assert ord[:lt?].(right(42), right(43)) == true
      assert ord[:gt?].(right(43), right(42)) == true
      assert ord[:le?].(right(42), right(42)) == true
      assert ord[:ge?].(right(42), right(42)) == true
    end

    test "Left is equal to Left in terms of ordering", %{ord: ord} do
      assert ord[:le?].(left(1), left(1)) == true
      assert ord[:ge?].(left(1), left(1)) == true
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
      false_func = fn -> "Predicate failed" end

      result =
        5
        |> lift_predicate(pred, false_func)

      assert result == right(5)
    end

    test "returns Left when the predicate is false" do
      pred = fn x -> x > 0 end
      false_func = fn -> "Predicate failed" end

      result =
        0
        |> lift_predicate(pred, false_func)

      assert result == left("Predicate failed")
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

      assert result == %Right{value: 42}
    end

    test "converts a raised exception into Left" do
      result = from_try(fn -> raise "error" end)

      assert result == %Left{value: %RuntimeError{message: "error"}}
    end
  end

  describe "to_try!/1" do
    test "returns value from Right" do
      right_result = %Right{value: 42}

      assert to_try!(right_result) == 42
    end

    test "raises RuntimeError for Left" do
      left_result = %Left{value: "something went wrong"}

      assert_raise RuntimeError, "something went wrong", fn ->
        to_try!(left_result)
      end
    end
  end
end
