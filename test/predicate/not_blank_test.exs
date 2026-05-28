defmodule Funx.Predicate.NotBlankTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.NotBlank

  describe "NotBlank predicate standalone" do
    test "returns true for non-blank strings" do
      predicate = NotBlank.pred()

      assert predicate.("hello")
      assert predicate.("hello world")
      assert predicate.("  hello  ")
      assert predicate.("a")
      assert predicate.("0")
    end

    test "returns false for blank strings" do
      predicate = NotBlank.pred()

      refute predicate.("")
      refute predicate.("   ")
      refute predicate.("\n")
      refute predicate.("\t")
      refute predicate.("\n\t ")
      refute predicate.("  \n  \t  ")
    end

    test "returns false for non-strings" do
      predicate = NotBlank.pred()

      refute predicate.(42)
      refute predicate.(nil)
      refute predicate.(:atom)
      refute predicate.([1, 2, 3])
      refute predicate.(%{key: "value"})
    end
  end

  describe "NotBlank predicate in DSL" do
    test "check with NotBlank" do
      has_name =
        pred do
          check :name, NotBlank
        end

      assert has_name.(%{name: "Alice"})
      assert has_name.(%{name: "  Bob  "})
      refute has_name.(%{name: ""})
      refute has_name.(%{name: "   "})
      refute has_name.(%{})
    end

    test "negate check with NotBlank" do
      is_blank_or_not_string =
        pred do
          negate check :value, NotBlank
        end

      assert is_blank_or_not_string.(%{value: ""})
      assert is_blank_or_not_string.(%{value: "   "})
      assert is_blank_or_not_string.(%{value: 42})
      refute is_blank_or_not_string.(%{value: "hello"})
    end

    test "combined with other predicates" do
      alias Funx.Predicate.Pattern

      valid_email_prefix =
        pred do
          check :email, NotBlank
          check :email, {Pattern, regex: ~r/@/}
        end

      assert valid_email_prefix.(%{email: "user@example.com"})
      refute valid_email_prefix.(%{email: ""})
      refute valid_email_prefix.(%{email: "   "})
      refute valid_email_prefix.(%{email: "no-at-sign"})
    end
  end
end
