defmodule Funx.Errors.ValidationErrorTest do
  use ExUnit.Case, async: true

  doctest Funx.Errors.ValidationError

  alias Funx.Errors.ValidationError

  describe "new/1" do
    test "constructs a ValidationError from a list of errors" do
      errors = ["must be positive"]
      ve = ValidationError.new(errors)

      assert %ValidationError{errors: ^errors} = ve
    end

    test "wraps the single error in a list" do
      ve = ValidationError.new("must be positive")
      assert ve == %ValidationError{errors: ["must be positive"]}
    end

    test "constructs an empty ValidationError" do
      ve = ValidationError.new([])

      assert %ValidationError{errors: []} = ve
    end
  end

  describe "merge/2" do
    test "combines errors from two ValidationError structs" do
      ve1 = ValidationError.new(["error 1"])
      ve2 = ValidationError.new(["error 2"])

      merged = ValidationError.merge(ve1, ve2)
      assert merged.errors == ["error 1", "error 2"]
    end

    test "merging with empty error list preserves existing errors" do
      ve1 = ValidationError.new(["only error"])
      ve2 = ValidationError.new([])

      assert ValidationError.merge(ve1, ve2).errors == ["only error"]
      assert ValidationError.merge(ve2, ve1).errors == ["only error"]
    end
  end

  describe "String.Chars implementation" do
    test "converts ValidationError to string" do
      ve = ValidationError.new(["must be even", "must be positive"])
      assert to_string(ve) == "ValidationError(must be even, must be positive)"
    end

    test "converts empty ValidationError to string" do
      ve = ValidationError.new([])
      assert to_string(ve) == "ValidationError()"
    end
  end

  describe "empty/0" do
    test "returns a ValidationError with no errors" do
      ve = ValidationError.empty()
      assert ve.errors == []
      assert ve == %ValidationError{errors: []}
    end
  end

  describe "from_tagged/1" do
    test "constructs a ValidationError from a tagged tuple" do
      tagged = {:error, ["error 1", "error 2"]}
      ve = ValidationError.from_tagged(tagged)

      assert ve == %ValidationError{errors: ["error 1", "error 2"]}
    end
  end

  describe "Funx.Summarizable implementation" do
    test "summarizes the validation error" do
      ve = ValidationError.new(["a", "b"])

      assert Funx.Summarizable.summarize(ve) ==
               {:validation_error, {:list, [string: "a", string: "b"]}}
    end

    test "summarizes an empty validation error" do
      ve = ValidationError.new([])

      assert Funx.Summarizable.summarize(ve) ==
               {:validation_error, {:list, :empty}}
    end
  end
end
