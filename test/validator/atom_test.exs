defmodule Funx.Validator.AtomTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.Atom

  alias Funx.Monad.Either
  alias Funx.Monad.Either.Right
  alias Funx.Validator.Atom

  describe "Atom validator" do
    test "passes for atoms" do
      assert Atom.validate(:ok) == %Right{right: :ok}
      assert Atom.validate(:error) == %Right{right: :error}
      assert Atom.validate(:hello_world) == %Right{right: :hello_world}
    end

    test "passes for boolean atoms" do
      assert Atom.validate(true) == %Right{right: true}
      assert Atom.validate(false) == %Right{right: false}
    end

    test "passes for nil" do
      assert Atom.validate(nil) == %Right{right: nil}
    end

    test "fails for non-atoms" do
      result = Atom.validate("atom")
      assert Either.left?(result)

      result = Atom.validate(42)
      assert Either.left?(result)
    end

    test "supports custom message callback" do
      result =
        Atom.validate("ok", message: fn _ -> "status must be an atom" end)

      assert Either.left?(result)
    end
  end

  describe "Atom validator with Maybe types" do
    alias Funx.Monad.Maybe.{Just, Nothing}

    test "passes for Nothing (optional field without value)" do
      assert Atom.validate(%Nothing{}, []) == %Right{right: %Nothing{}}
    end

    test "passes for Just containing atom" do
      assert Atom.validate(%Just{value: :ok}, []) == %Right{right: :ok}
    end

    test "fails for Just containing non-atom" do
      result = Atom.validate(%Just{value: "atom"}, [])
      assert Either.left?(result)
    end

    test "works with custom message on Just values" do
      result =
        Atom.validate(%Just{value: "ok"},
          message: fn _ -> "status must be an atom" end
        )

      assert Either.left?(result)
    end

    test "Nothing passes regardless of custom message" do
      assert Atom.validate(%Nothing{}, message: fn _ -> "should not see this" end) ==
               %Right{right: %Nothing{}}
    end
  end
end
