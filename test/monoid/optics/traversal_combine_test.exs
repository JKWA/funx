defmodule Funx.Monoid.Optics.TraversalCombineTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Funx.Monoid

  alias Funx.Monoid.Optics.TraversalCombine
  alias Funx.Optics.{Lens, Prism, Traversal}

  describe "empty/1" do
    test "returns a TraversalCombine with an empty traversal (no foci)" do
      result = empty(%TraversalCombine{})
      assert %TraversalCombine{traversal: %Traversal{foci: []}} = result
    end
  end

  describe "wrap/2" do
    test "wraps a Lens into a single-focus traversal" do
      lens = Lens.key(:name)
      result = wrap(%TraversalCombine{}, lens)

      assert %TraversalCombine{traversal: %Traversal{foci: [^lens]}} = result
    end

    test "wraps a Prism into a single-focus traversal" do
      prism = Prism.key(:email)
      result = wrap(%TraversalCombine{}, prism)

      assert %TraversalCombine{traversal: %Traversal{foci: [^prism]}} = result
    end
  end

  describe "unwrap/1" do
    test "unwraps a Traversal from a TraversalCombine (via protocol)" do
      traversal = %Traversal{foci: [Lens.key(:name), Lens.key(:age)]}
      wrapped = %TraversalCombine{traversal: traversal}

      assert unwrap(wrapped) == traversal
    end

    test "unwraps a Traversal from a TraversalCombine (via module function)" do
      traversal = %Traversal{foci: [Lens.key(:name), Lens.key(:age)]}
      wrapped = %TraversalCombine{traversal: traversal}

      assert TraversalCombine.unwrap(wrapped) == traversal
    end

    test "unwraps an empty traversal" do
      empty_wrapped = empty(%TraversalCombine{})
      assert %Traversal{foci: []} = unwrap(empty_wrapped)
    end
  end

  describe "append/2" do
    test "combines two TraversalCombines by concatenating their foci" do
      lens1 = Lens.key(:name)
      lens2 = Lens.key(:age)
      prism1 = Prism.key(:email)

      tc1 = %TraversalCombine{traversal: %Traversal{foci: [lens1]}}
      tc2 = %TraversalCombine{traversal: %Traversal{foci: [lens2, prism1]}}

      result = append(tc1, tc2)

      assert %TraversalCombine{
               traversal: %Traversal{foci: [^lens1, ^lens2, ^prism1]}
             } = result
    end

    test "appending with empty identity returns the original" do
      lens = Lens.key(:name)
      tc = %TraversalCombine{traversal: %Traversal{foci: [lens]}}
      empty_tc = empty(%TraversalCombine{})

      assert append(tc, empty_tc) == tc
      assert append(empty_tc, tc) == tc
    end

    test "appending two empty TraversalCombines returns empty" do
      empty_tc = empty(%TraversalCombine{})
      result = append(empty_tc, empty_tc)

      assert result == empty_tc
    end
  end

  describe "monoid laws" do
    test "left identity: empty <> a = a" do
      lens = Lens.key(:name)
      tc = wrap(%TraversalCombine{}, lens)
      empty_tc = empty(%TraversalCombine{})

      assert append(empty_tc, tc) == tc
    end

    test "right identity: a <> empty = a" do
      prism = Prism.key(:email)
      tc = wrap(%TraversalCombine{}, prism)
      empty_tc = empty(%TraversalCombine{})

      assert append(tc, empty_tc) == tc
    end

    test "associativity: (a <> b) <> c = a <> (b <> c)" do
      lens1 = Lens.key(:name)
      lens2 = Lens.key(:age)
      prism = Prism.key(:email)

      tc1 = wrap(%TraversalCombine{}, lens1)
      tc2 = wrap(%TraversalCombine{}, lens2)
      tc3 = wrap(%TraversalCombine{}, prism)

      left_assoc = append(append(tc1, tc2), tc3)
      right_assoc = append(tc1, append(tc2, tc3))

      assert left_assoc == right_assoc
    end
  end

  describe "integration with Traversal.combine/1" do
    test "combine uses TraversalCombine monoid correctly" do
      lens1 = Lens.key(:name)
      lens2 = Lens.key(:age)

      # This tests that Traversal.combine delegates to m_concat correctly
      t = Traversal.combine([lens1, lens2])

      assert %Traversal{foci: [^lens1, ^lens2]} = t
    end

    test "combine with empty list creates empty traversal" do
      t = Traversal.combine([])

      assert %Traversal{foci: []} = t
    end

    test "combine preserves order" do
      prism = Prism.key(:email)
      lens = Lens.key(:name)

      t = Traversal.combine([prism, lens])

      assert %Traversal{foci: [^prism, ^lens]} = t
    end
  end
end
