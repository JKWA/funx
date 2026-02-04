defmodule Funx.Predicate.PatternTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{Pattern, Required}

  describe "Pattern predicate standalone" do
    test "returns true when string matches regex" do
      predicate = Pattern.pred(regex: ~r/^[A-Z]+$/)

      assert predicate.("ABC")
      assert predicate.("HELLO")
      refute predicate.("abc")
      refute predicate.("Hello")
      refute predicate.("123")
    end

    test "returns true for partial matches" do
      predicate = Pattern.pred(regex: ~r/@/)

      assert predicate.("test@example.com")
      assert predicate.("@")
      refute predicate.("no at sign")
    end

    test "works with anchored patterns" do
      predicate = Pattern.pred(regex: ~r/^\d{3}-\d{4}$/)

      assert predicate.("123-4567")
      refute predicate.("12-4567")
      refute predicate.("123-456")
      refute predicate.("prefix 123-4567 suffix")
    end

    test "returns false for non-strings" do
      predicate = Pattern.pred(regex: ~r/.*/)

      refute predicate.(123)
      refute predicate.(nil)
      refute predicate.([:a, :b])
      refute predicate.(%{})
    end
  end

  describe "Pattern predicate in DSL" do
    test "check with Pattern" do
      valid_code =
        pred do
          check :code, {Pattern, regex: ~r/^[A-Z]{3}$/}
        end

      assert valid_code.(%{code: "ABC"})
      assert valid_code.(%{code: "XYZ"})
      refute valid_code.(%{code: "AB"})
      refute valid_code.(%{code: "ABCD"})
      refute valid_code.(%{code: "abc"})
      refute valid_code.(%{})
    end

    test "negate check with Pattern" do
      invalid_format =
        pred do
          negate check :code, {Pattern, regex: ~r/^[A-Z]+$/}
        end

      assert invalid_format.(%{code: "abc"})
      assert invalid_format.(%{code: "123"})
      refute invalid_format.(%{code: "ABC"})
    end

    test "combined with Required" do
      valid_email =
        pred do
          check :email, Required
          check :email, {Pattern, regex: ~r/@/}
        end

      assert valid_email.(%{email: "test@example.com"})
      refute valid_email.(%{email: "invalid"})
      refute valid_email.(%{email: ""})
      refute valid_email.(%{email: nil})
    end
  end
end
