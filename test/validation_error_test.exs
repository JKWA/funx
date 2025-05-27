defmodule Funx.Errors.ValidationErrorTest do
  use ExUnit.Case, async: true

  doctest Funx.Semigroup
  doctest Funx.Errors.ValidationError

  import Funx.Errors.ValidationError
  import Funx.Semigroup

  alias Funx.Eq
  alias Funx.Ord

  alias Funx.Errors.ValidationError

  describe "new/1" do
    test "constructs a ValidationError from a list of errors" do
      errors = ["must be positive"]
      ve = new(errors)

      assert %ValidationError{errors: ^errors} = ve
    end

    test "wraps the single error in a list" do
      ve = new("must be positive")
      assert ve == %ValidationError{errors: ["must be positive"]}
    end

    test "constructs an empty ValidationError" do
      ve = new([])

      assert %ValidationError{errors: []} = ve
    end
  end

  describe "merge/2" do
    test "appends errors from two ValidationError structs" do
      ve1 = new(["error 1"])
      ve2 = new(["error 2"])

      merged = ValidationError.merge(ve1, ve2)
      assert merged.errors == ["error 1", "error 2"]
    end

    test "merging with empty error list preserves existing errors" do
      ve1 = new(["only error"])
      ve2 = new([])

      assert ValidationError.merge(ve1, ve2).errors == ["only error"]
      assert ValidationError.merge(ve2, ve1).errors == ["only error"]
    end
  end

  describe "Exception implementation" do
    test "raises with keyword arguments" do
      assert_raise ValidationError, "must be positive", fn ->
        raise ValidationError, errors: ["must be positive"]
      end
    end

    test "raises with binary message" do
      assert_raise ValidationError, "invalid input", fn ->
        raise ValidationError, "invalid input"
      end
    end

    test "exception/1 with keyword args builds struct" do
      result = ValidationError.exception(errors: ["a", "b"])
      assert %ValidationError{errors: ["a", "b"]} = result
    end

    test "exception/1 with binary builds struct with single error" do
      result = ValidationError.exception("only one")
      assert %ValidationError{errors: ["only one"]} = result
    end

    test "message/1 formats joined errors" do
      error = %ValidationError{errors: ["x", "y"]}
      assert Exception.message(error) == "x, y"
    end

    test "to_string uses custom String.Chars implementation" do
      error = %ValidationError{errors: ["foo", "bar"]}
      assert to_string(error) == "ValidationError(foo, bar)"
    end
  end

  describe "Funx.Semigroup implementation for ValidationError" do
    test "coerce/1 returns existing ValidationError unchanged" do
      original = new("already wrapped")
      assert coerce(original) == original
    end
  end

  describe "String.Chars implementation" do
    test "converts ValidationError to string" do
      ve = new(["must be even", "must be positive"])
      assert to_string(ve) == "ValidationError(must be even, must be positive)"
    end

    test "converts empty ValidationError to string" do
      ve = new([])
      assert to_string(ve) == "ValidationError()"
    end
  end

  describe "empty/0" do
    test "returns a ValidationError with no errors" do
      ve = empty()
      assert ve.errors == []
      assert ve == %ValidationError{errors: []}
    end
  end

  describe "from_tagged/1" do
    test "constructs a ValidationError from a tagged tuple" do
      tagged = {:error, ["error 1", "error 2"]}
      ve = from_tagged(tagged)

      assert ve == %ValidationError{errors: ["error 1", "error 2"]}
    end
  end

  describe "Funx.Summarizable implementation" do
    test "summarizes the validation error" do
      ve = new(["a", "b"])

      assert Funx.Summarizable.summarize(ve) ==
               {:validation_error, {:list, [string: "a", string: "b"]}}
    end

    test "summarizes an empty validation error" do
      ve = new([])

      assert Funx.Summarizable.summarize(ve) ==
               {:validation_error, {:list, :empty}}
    end
  end

  describe "Eq.eq?/2" do
    test "returns true for equal Just values" do
      assert Eq.eq?(new(1), new(1)) == true
    end

    test "returns false for different Just values" do
      assert Eq.eq?(new(1), new(2)) == false
    end
  end

  describe "Eq.not_eq?/2" do
    test "returns false for equal Just values" do
      assert Eq.not_eq?(new(1), new(1)) == false
    end

    test "returns true for different Just values" do
      assert Eq.not_eq?(new(1), new(2)) == true
    end
  end

  describe "Ord.lt?/2" do
    test "Identity returns true for less value" do
      assert Ord.lt?(new(1), new(2)) == true
    end

    test "Identity returns false for more value" do
      assert Ord.lt?(new(2), new(1)) == false
    end

    test "Identity returns false for equal values" do
      assert Ord.lt?(new(1), new(1)) == false
    end
  end

  describe "Ord.le?/2" do
    test "Identity returns true for less value" do
      assert Ord.le?(new(1), new(2)) == true
    end

    test "Identity returns true for equal values" do
      assert Ord.le?(new(1), new(1)) == true
    end

    test "Identity returns false for greater value" do
      assert Ord.le?(new(2), new(1)) == false
    end
  end

  describe "Ord.gt?/2" do
    test "Identity returns true for greater value" do
      assert Ord.gt?(new(2), new(1)) == true
    end

    test "Identity returns false for less value" do
      assert Ord.gt?(new(1), new(2)) == false
    end

    test "Identity returns false for equal values" do
      assert Ord.gt?(new(1), new(1)) == false
    end
  end

  describe "Ord.ge?/2" do
    test "Identity returns true for greater value" do
      assert Ord.ge?(new(2), new(1)) == true
    end

    test "Identity returns true for equal values" do
      assert Ord.ge?(new(1), new(1)) == true
    end

    test "Identity returns false for less value" do
      assert Ord.ge?(new(1), new(2)) == false
    end
  end
end
