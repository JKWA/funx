defmodule Funx.Errors.EffectErrorTest do
  use ExUnit.Case, async: true

  doctest Funx.Errors.EffectError

  alias Funx.Errors.EffectError

  describe "new/2" do
    test "creates a struct with given stage and reason" do
      error = EffectError.new(:map, %RuntimeError{message: "boom"})
      assert %EffectError{stage: :map, reason: %RuntimeError{message: "boom"}} = error
    end
  end

  describe "Exception behaviour" do
    test "exception/1 builds struct from keyword list" do
      exception = EffectError.exception(%{stage: :bind, reason: %ArgumentError{message: "bad"}})
      assert %EffectError{stage: :bind, reason: %ArgumentError{message: "bad"}} = exception
    end

    test "message/1 formats message using Exception.message" do
      error = EffectError.new(:ap, %RuntimeError{message: "fail"})
      assert Exception.message(error) == "EffectError at ap: fail"
    end

    test "message/1 falls back to inspect on non-exception reason" do
      error = EffectError.new(:bind, :boom)
      assert Exception.message(error) == "EffectError at bind: :boom"
    end
  end

  describe "String.Chars implementation" do
    test "to_string/1 produces readable string" do
      error = EffectError.new(:map, %RuntimeError{message: "boom"})
      assert to_string(error) == "EffectError(map: %RuntimeError{message: \"boom\"})"
    end
  end

  describe "Summarizable implementation" do
    test "summarize/1 returns a tagged tuple with stage and reason" do
      error = EffectError.new(:ap, %RuntimeError{message: "oops"})

      assert Funx.Summarizable.summarize(error) ==
               {:effect_error, [stage: :ap, reason: {:exception, {:runtime, "oops"}}]}
    end
  end
end
