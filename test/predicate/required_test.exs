defmodule Funx.Predicate.RequiredTest do
  use ExUnit.Case, async: true
  use Funx.Predicate

  alias Funx.Predicate.{MinLength, Required}

  describe "Required predicate standalone" do
    test "returns true for non-nil, non-empty values" do
      predicate = Required.pred()

      assert predicate.("hello")
      assert predicate.("a")
      assert predicate.(123)
      assert predicate.(%{key: "value"})
      assert predicate.([:a, :b])
    end

    test "returns true for falsy but present values" do
      predicate = Required.pred()

      assert predicate.(false)
      assert predicate.(0)
      assert predicate.([])
      assert predicate.(%{})
    end

    test "returns false for nil" do
      predicate = Required.pred()

      refute predicate.(nil)
    end

    test "returns false for empty string" do
      predicate = Required.pred()

      refute predicate.("")
    end
  end

  describe "Required predicate in DSL" do
    test "check with Required" do
      has_name =
        pred do
          check :name, Required
        end

      assert has_name.(%{name: "Joe"})
      assert has_name.(%{name: "a"})
      refute has_name.(%{name: nil})
      refute has_name.(%{name: ""})
      refute has_name.(%{})
    end

    test "passes for falsy but present values" do
      has_value =
        pred do
          check :value, Required
        end

      assert has_value.(%{value: false})
      assert has_value.(%{value: 0})
      assert has_value.(%{value: []})
    end

    test "negate check with Required" do
      missing_or_empty =
        pred do
          negate check :name, Required
        end

      assert missing_or_empty.(%{name: nil})
      assert missing_or_empty.(%{name: ""})
      refute missing_or_empty.(%{name: "Joe"})
    end

    test "combined with other predicates" do
      valid_name =
        pred do
          check :name, Required
          check :name, {MinLength, min: 2}
        end

      assert valid_name.(%{name: "Joe"})
      refute valid_name.(%{name: "J"})
      refute valid_name.(%{name: ""})
      refute valid_name.(%{name: nil})
    end
  end

  describe "Required vs truthy" do
    test "Required passes for false, truthy does not" do
      required_check =
        pred do
          check :enabled, Required
        end

      truthy_check =
        pred do
          check :enabled
        end

      # false is present but falsy
      assert required_check.(%{enabled: false})
      refute truthy_check.(%{enabled: false})
    end

    test "Required passes for 0, truthy passes too" do
      required_check =
        pred do
          check :count, Required
        end

      truthy_check =
        pred do
          check :count
        end

      # 0 is present and truthy in Elixir
      assert required_check.(%{count: 0})
      assert truthy_check.(%{count: 0})
    end
  end
end
