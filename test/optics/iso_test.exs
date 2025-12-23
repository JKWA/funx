defmodule Funx.Optics.IsoTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Funx.Optics.Iso

  alias Funx.Optics.{Iso, Lens, Prism}

  # ============================================================================
  # Test Fixtures
  # ============================================================================

  defp string_int_iso do
    Iso.make(
      fn s -> String.to_integer(s) end,
      fn i -> Integer.to_string(i) end
    )
  end

  defp celsius_fahrenheit_iso do
    Iso.make(
      fn c -> c * 9 / 5 + 32 end,
      fn f -> (f - 32) * 5 / 9 end
    )
  end

  defp double_iso do
    Iso.make(
      fn i -> i * 2 end,
      fn i -> div(i, 2) end
    )
  end

  defp add_offset_iso(offset) do
    Iso.make(
      fn x -> x + offset end,
      fn x -> x - offset end
    )
  end

  # ============================================================================
  # Constructor Tests
  # ============================================================================

  describe "make/2" do
    test "creates an iso with viewer and reviewer functions" do
      iso = string_int_iso()

      assert Iso.view("42", iso) == 42
      assert Iso.review(42, iso) == "42"
    end

    test "satisfies round-trip property: review(view(s, iso), iso) == s" do
      iso = string_int_iso()

      original = "42"
      result = original |> Iso.view(iso) |> then(&Iso.review(&1, iso))
      assert result == original
    end

    test "satisfies round-trip property: view(review(a, iso), iso) == a" do
      iso = string_int_iso()

      original = 42
      result = original |> Iso.review(iso) |> then(&Iso.view(&1, iso))
      assert result == original
    end
  end

  describe "identity/0" do
    test "returns an iso that doesn't change values in either direction" do
      iso = Iso.identity()

      assert Iso.view(42, iso) == 42
      assert Iso.review("hello", iso) == "hello"
      assert Iso.view([1, 2, 3], iso) == [1, 2, 3]
    end
  end

  # ============================================================================
  # Basic Operations Tests
  # ============================================================================

  describe "view/2" do
    test "applies the forward transformation" do
      iso = celsius_fahrenheit_iso()

      assert Iso.view(0, iso) == 32.0
      assert Iso.view(100, iso) == 212.0
    end
  end

  describe "review/2" do
    test "applies the backward transformation" do
      iso = celsius_fahrenheit_iso()

      assert Iso.review(32, iso) == 0.0
      assert Iso.review(212, iso) == 100.0
    end
  end

  describe "over/3" do
    test "modifies the viewed side" do
      iso = string_int_iso()

      # "10" -> 10 -> 50 -> "50"
      assert Iso.over("10", iso, fn i -> i * 5 end) == "50"
    end

    test "preserves round-trip property" do
      iso = string_int_iso()

      # over with identity should return the original
      assert Iso.over("42", iso, fn i -> i end) == "42"
    end
  end

  describe "under/3" do
    test "modifies the reviewed side" do
      iso = string_int_iso()

      # 100 -> "100" -> "1000" -> 1000
      assert Iso.under(100, iso, fn s -> s <> "0" end) == 1000
    end

    test "preserves round-trip property" do
      iso = string_int_iso()

      # under with identity should return the original
      assert Iso.under(42, iso, fn s -> s end) == 42
    end

    test "is unique to Iso due to bidirectional symmetry" do
      # under goes review -> f -> view
      # over goes view -> f -> review

      reverse_list =
        Iso.make(
          fn list -> Enum.reverse(list) end,
          fn list -> Enum.reverse(list) end
        )

      # over: [1,2,3] -> [3,2,1] -> [3,2,1,4] -> [4,1,2,3]
      assert Iso.over([1, 2, 3], reverse_list, fn list -> list ++ [4] end) == [4, 1, 2, 3]

      # under: [1,2,3] -> [3,2,1] -> [3,2,1,4] -> [4,1,2,3]
      # In this case they're the same because reverse is its own inverse
      assert Iso.under([1, 2, 3], reverse_list, fn list -> list ++ [4] end) == [4, 1, 2, 3]
    end
  end

  # ============================================================================
  # Composition Tests
  # ============================================================================

  describe "from/1" do
    test "reverses the iso's direction" do
      iso = string_int_iso()
      int_string = Iso.from(iso)

      # Original: view converts string to int
      assert Iso.view("42", iso) == 42
      # Reversed: view converts int to string
      assert Iso.view(42, int_string) == "42"

      # Original: review converts int to string
      assert Iso.review(42, iso) == "42"
      # Reversed: review converts string to int
      assert Iso.review("42", int_string) == 42
    end

    test "double reversal returns to original direction" do
      iso = string_int_iso()

      reversed_twice = iso |> Iso.from() |> Iso.from()

      assert Iso.view("42", reversed_twice) == 42
      assert Iso.review(42, reversed_twice) == "42"
    end
  end

  describe "compose/2" do
    test "composes two isos sequentially" do
      iso = string_int_iso()
      double = double_iso()

      # string <-> doubled int
      composed = Iso.compose(iso, double)

      assert Iso.view("21", composed) == 42
      assert Iso.review(42, composed) == "21"
    end

    test "composition satisfies round-trip laws" do
      iso = string_int_iso()
      double = double_iso()
      composed = Iso.compose(iso, double)

      # review(view(s, iso), iso) == s
      assert "21" |> Iso.view(composed) |> then(&Iso.review(&1, composed)) == "21"

      # view(review(a, iso), iso) == a
      assert 42 |> Iso.review(composed) |> then(&Iso.view(&1, composed)) == 42
    end

    test "composing with identity has no effect" do
      iso = string_int_iso()
      id = Iso.identity()

      # Compose with identity on left
      left = Iso.compose(id, iso)
      assert Iso.view("42", left) == 42
      assert Iso.review(42, left) == "42"

      # Compose with identity on right
      right = Iso.compose(iso, id)
      assert Iso.view("42", right) == 42
      assert Iso.review(42, right) == "42"
    end
  end

  describe "compose/1 list composition" do
    test "composes multiple isos in sequence" do
      isos = [
        string_int_iso(),
        double_iso(),
        add_offset_iso(10)
      ]

      composed = Iso.compose(isos)

      # "21" -> 21 -> 42 -> 52
      assert Iso.view("21", composed) == 52
      # 52 -> 42 -> 21 -> "21"
      assert Iso.review(52, composed) == "21"
    end

    test "composing empty list returns identity" do
      composed = Iso.compose([])

      assert Iso.view(42, composed) == 42
      assert Iso.review("hello", composed) == "hello"
    end

    test "composing single iso returns that iso (behaviorally)" do
      iso = string_int_iso()
      composed = Iso.compose([iso])

      assert Iso.view("42", composed) == 42
      assert Iso.review(42, composed) == "42"
    end
  end

  # ============================================================================
  # Conversion to Other Optics
  # ============================================================================

  describe "as_lens/1" do
    test "converts iso to lens with correct view operation" do
      iso = string_int_iso()
      lens = Iso.as_lens(iso)

      assert Lens.view!("42", lens) == 42
      assert Lens.view!("100", lens) == 100
    end

    test "converts iso to lens with correct set operation" do
      iso = string_int_iso()
      lens = Iso.as_lens(iso)

      # Set ignores the old value and uses iso's review
      assert Lens.set!("42", lens, 99) == "99"
      assert Lens.set!("anything", lens, 0) == "0"
    end

    test "converts iso to lens with correct over operation" do
      iso = string_int_iso()
      lens = Iso.as_lens(iso)

      # "10" -> 10 -> 50 -> "50"
      assert Lens.over!("10", lens, fn i -> i * 5 end) == "50"
      assert Lens.over!("7", lens, fn i -> i + 3 end) == "10"
    end

    test "resulting lens works with nested data" do
      iso = string_int_iso()
      iso_lens = Iso.as_lens(iso)
      key_lens = Lens.key(:value)
      composed = Lens.compose(key_lens, iso_lens)

      data = %{value: "42"}

      assert Lens.view!(data, composed) == 42
      assert Lens.set!(data, composed, 99) == %{value: "99"}
    end
  end

  describe "as_prism/1" do
    test "converts iso to prism with preview that always succeeds" do
      alias Funx.Monad.Maybe.Just

      iso = string_int_iso()
      prism = Iso.as_prism(iso)

      # Preview always returns Just (never Nothing)
      assert Prism.preview("42", prism) == %Just{value: 42}
      assert Prism.preview("100", prism) == %Just{value: 100}
    end

    test "converts iso to prism with correct review operation" do
      iso = string_int_iso()
      prism = Iso.as_prism(iso)

      assert Prism.review(42, prism) == "42"
      assert Prism.review(0, prism) == "0"
    end

    test "resulting prism satisfies round-trip property" do
      alias Funx.Monad.Maybe.Just

      iso = string_int_iso()
      prism = Iso.as_prism(iso)

      # preview then review
      original = "42"
      %Just{value: viewed} = Prism.preview(original, prism)
      assert Prism.review(viewed, prism) == original

      # review then preview
      original_int = 42
      reviewed = Prism.review(original_int, prism)
      assert Prism.preview(reviewed, prism) == %Just{value: original_int}
    end

    test "resulting prism composes with other prisms" do
      alias Funx.Monad.Maybe.Just

      iso = string_int_iso()
      iso_prism = Iso.as_prism(iso)
      key_prism = Prism.key(:value)
      composed = Prism.compose(key_prism, iso_prism)

      # Success case
      assert Prism.preview(%{value: "42"}, composed) == %Just{value: 42}
      assert Prism.review(42, composed) == %{value: "42"}

      # Failure case (missing key) - fails at the key prism, not the iso
      assert Prism.preview(%{other: "42"}, composed) == %Funx.Monad.Maybe.Nothing{}
    end
  end

  # ============================================================================
  # Monoid Structure Tests
  # ============================================================================

  describe "Monoid structure via IsoCompose" do
    alias Funx.Monoid.Optics.IsoCompose

    test "isos form a monoid under composition via IsoCompose" do
      import Funx.Monoid

      i1 = IsoCompose.new(string_int_iso())
      i2 = IsoCompose.new(double_iso())

      # Composition via Monoid.append
      composed = append(i1, i2) |> IsoCompose.unwrap()

      assert Iso.view("21", composed) == 42
      assert Iso.review(42, composed) == "21"
    end

    test "identity iso preserves values in both directions" do
      import Funx.Monoid

      id = empty(%IsoCompose{})
      i = IsoCompose.new(string_int_iso())

      # Left identity: append(id, i) == i
      left = append(id, i) |> IsoCompose.unwrap()
      assert Iso.view("42", left) == 42
      assert Iso.review(42, left) == "42"

      # Right identity: append(i, id) == i
      right = append(i, id) |> IsoCompose.unwrap()
      assert Iso.view("42", right) == 42
      assert Iso.review(42, right) == "42"
    end

    test "composition is associative" do
      import Funx.Monoid

      i1 = IsoCompose.new(string_int_iso())
      i2 = IsoCompose.new(double_iso())
      i3 = IsoCompose.new(add_offset_iso(10))

      # (i1 . i2) . i3 == i1 . (i2 . i3)
      left_assoc = append(append(i1, i2), i3) |> IsoCompose.unwrap()
      right_assoc = append(i1, append(i2, i3)) |> IsoCompose.unwrap()

      # Both should view the same value
      assert Iso.view("5", left_assoc) == 20
      assert Iso.view("5", right_assoc) == 20

      # Both should review the same way
      assert Iso.review(20, left_assoc) == "5"
      assert Iso.review(20, right_assoc) == "5"
    end

    test "compose/1 uses monoid structure correctly" do
      isos = [
        string_int_iso(),
        double_iso(),
        add_offset_iso(10)
      ]

      composed = Iso.compose(isos)

      # "5" -> 5 -> 10 -> 20
      assert Iso.view("5", composed) == 20
      # 20 -> 10 -> 5 -> "5"
      assert Iso.review(20, composed) == "5"
    end

    test "unwrap extracts the iso from IsoCompose wrapper" do
      iso = string_int_iso()
      wrapped = IsoCompose.new(iso)
      unwrapped = IsoCompose.unwrap(wrapped)

      # The unwrapped iso should behave identically
      assert Iso.view("42", unwrapped) == 42
      assert Iso.review(42, unwrapped) == "42"
    end

    test "wrap wraps an iso into IsoCompose" do
      import Funx.Monoid

      iso = string_int_iso()
      wrapped = wrap(%IsoCompose{}, iso)

      assert %IsoCompose{iso: wrapped_iso} = wrapped
      assert Iso.view("42", wrapped_iso) == 42
      assert Iso.review(42, wrapped_iso) == "42"
    end
  end

  # ============================================================================
  # Practical Examples
  # ============================================================================

  describe "practical examples" do
    test "encoding and decoding map key transformations" do
      # Map with string keys <-> Map with atom keys
      atomize =
        Iso.make(
          fn map -> Map.new(map, fn {k, v} -> {String.to_atom(k), v} end) end,
          fn map -> Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end) end
        )

      string_map = %{"name" => "Alice", "age" => "30"}
      atom_map = %{name: "Alice", age: "30"}

      assert Iso.view(string_map, atomize) == atom_map
      assert Iso.review(atom_map, atomize) == string_map
    end

    test "unit conversions" do
      # Meters <-> Centimeters
      meters_cm =
        Iso.make(
          fn m -> m * 100 end,
          fn cm -> cm / 100 end
        )

      assert Iso.view(1.5, meters_cm) == 150.0
      assert Iso.review(150, meters_cm) == 1.5
    end

    test "data structure transformations" do
      # List <-> Reversed list
      reverse_iso =
        Iso.make(
          fn list -> Enum.reverse(list) end,
          fn list -> Enum.reverse(list) end
        )

      assert Iso.view([1, 2, 3], reverse_iso) == [3, 2, 1]
      assert Iso.review([3, 2, 1], reverse_iso) == [1, 2, 3]

      # Round-trip
      original = [1, 2, 3, 4, 5]
      result = original |> Iso.view(reverse_iso) |> then(&Iso.review(&1, reverse_iso))
      assert result == original
    end

    test "boolean to integer encoding" do
      bool_int =
        Iso.make(
          fn
            true -> 1
            false -> 0
          end,
          fn
            1 -> true
            0 -> false
          end
        )

      assert Iso.view(true, bool_int) == 1
      assert Iso.view(false, bool_int) == 0
      assert Iso.review(1, bool_int) == true
      assert Iso.review(0, bool_int) == false
    end

    test "tuple swap" do
      tuple_swap =
        Iso.make(
          fn {a, b} -> {b, a} end,
          fn {b, a} -> {a, b} end
        )

      assert Iso.view({1, 2}, tuple_swap) == {2, 1}
      assert Iso.review({2, 1}, tuple_swap) == {1, 2}
    end
  end

  # ============================================================================
  # Contract Enforcement Tests
  # ============================================================================

  describe "contract enforcement" do
    test "iso operations are total - crashes indicate broken iso" do
      # This iso is deliberately broken - the functions are not inverses
      broken_iso =
        Iso.make(
          fn s -> String.to_integer(s) end,
          fn _i -> "broken" end
        )

      # The operations themselves don't raise - they're total
      assert Iso.view("42", broken_iso) == 42
      assert Iso.review(100, broken_iso) == "broken"

      # But the round-trip law is violated - this is a contract violation
      result = "42" |> Iso.view(broken_iso) |> then(&Iso.review(&1, broken_iso))
      refute result == "42"
    end

    test "user function crashes are not optic failures" do
      # If the user function crashes, that's a broken iso, not an optic failure
      crashy_iso =
        Iso.make(
          fn _s -> raise "deliberate crash" end,
          fn i -> i end
        )

      # The crash is immediate and unambiguous
      assert_raise RuntimeError, "deliberate crash", fn ->
        Iso.view("test", crashy_iso)
      end
    end
  end

  # ============================================================================
  # Property-Based Tests
  # ============================================================================

  describe "property: round-trip laws" do
    property "review(view(s, iso), iso) == s for integer addition" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)

        # View then review should return original
        result = value |> Iso.view(iso) |> then(&Iso.review(&1, iso))

        assert result == value
      end
    end

    property "view(review(a, iso), iso) == a for integer addition" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)

        # Review then view should return original
        result = value |> Iso.review(iso) |> then(&Iso.view(&1, iso))

        assert result == value
      end
    end

    property "review(view(s, iso), iso) == s for multiplication" do
      check all(
              value <- integer(1..1000),
              multiplier <- integer(1..100)
            ) do
        iso = Iso.make(fn x -> x * multiplier end, fn x -> div(x, multiplier) end)

        result = value |> Iso.view(iso) |> then(&Iso.review(&1, iso))

        assert result == value
      end
    end

    property "view(review(a, iso), iso) == a for multiplication" do
      check all(
              base <- integer(1..1000),
              multiplier <- integer(1..100)
            ) do
        # Ensure value is divisible by multiplier for perfect round-trip
        value = base * multiplier
        iso = Iso.make(fn x -> x * multiplier end, fn x -> div(x, multiplier) end)

        result = value |> Iso.review(iso) |> then(&Iso.view(&1, iso))

        assert result == value
      end
    end
  end

  describe "property: identity laws" do
    property "identity iso satisfies view(x) == x" do
      check all(value <- one_of([integer(), string(:alphanumeric), boolean()])) do
        iso = Iso.identity()

        assert Iso.view(value, iso) == value
      end
    end

    property "identity iso satisfies review(x) == x" do
      check all(value <- one_of([integer(), string(:alphanumeric), boolean()])) do
        iso = Iso.identity()

        assert Iso.review(value, iso) == value
      end
    end
  end

  describe "property: composition laws" do
    property "composition is associative" do
      check all(
              offset1 <- integer(-100..100),
              offset2 <- integer(-100..100),
              offset3 <- integer(-100..100),
              value <- integer()
            ) do
        i1 = add_offset_iso(offset1)
        i2 = add_offset_iso(offset2)
        i3 = add_offset_iso(offset3)

        # (i1 . i2) . i3 vs i1 . (i2 . i3)
        left_assoc = Iso.compose(Iso.compose(i1, i2), i3)
        right_assoc = Iso.compose(i1, Iso.compose(i2, i3))

        # Both should view to the same result
        assert Iso.view(value, left_assoc) == Iso.view(value, right_assoc)

        # Both should review to the same result
        viewed = Iso.view(value, left_assoc)
        assert Iso.review(viewed, left_assoc) == Iso.review(viewed, right_assoc)
      end
    end

    property "composing with identity on left has no effect" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)
        id = Iso.identity()

        composed = Iso.compose(id, iso)

        assert Iso.view(value, composed) == Iso.view(value, iso)
        assert Iso.review(value, composed) == Iso.review(value, iso)
      end
    end

    property "composing with identity on right has no effect" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)
        id = Iso.identity()

        composed = Iso.compose(iso, id)

        assert Iso.view(value, composed) == Iso.view(value, iso)
        assert Iso.review(value, composed) == Iso.review(value, iso)
      end
    end
  end

  describe "property: from involution" do
    property "from(from(iso)) behaves like iso" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)

        reversed_twice = iso |> Iso.from() |> Iso.from()

        # Should behave identically to original
        assert Iso.view(value, reversed_twice) == Iso.view(value, iso)
        assert Iso.review(value, reversed_twice) == Iso.review(value, iso)
      end
    end

    property "from reverses direction: view becomes review and vice versa" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)
        reversed = Iso.from(iso)

        # Original iso's view should equal reversed iso's review
        assert Iso.view(value, iso) == Iso.review(value, reversed)

        # Original iso's review should equal reversed iso's view
        assert Iso.review(value, iso) == Iso.view(value, reversed)
      end
    end
  end

  describe "property: over and under operations" do
    property "over with identity function returns original" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)

        result = Iso.over(value, iso, fn x -> x end)

        assert result == value
      end
    end

    property "under with identity function returns original" do
      check all(value <- integer(), offset <- integer()) do
        iso = add_offset_iso(offset)

        result = Iso.under(value, iso, fn x -> x end)

        assert result == value
      end
    end

    property "over and under are related through view/review" do
      check all(
              value <- integer(1..1000),
              add_amount <- integer(1..100)
            ) do
        iso = Iso.make(fn x -> x * 2 end, fn x -> div(x, 2) end)

        # over: view -> f -> review
        over_result = Iso.over(value, iso, fn x -> x + add_amount end)

        # Manual equivalent
        manual_result =
          value |> Iso.view(iso) |> Kernel.+(add_amount) |> then(&Iso.review(&1, iso))

        assert over_result == manual_result
      end
    end
  end

  describe "property: composed isos" do
    property "composed isos satisfy round-trip laws" do
      check all(
              value <- integer(),
              offset1 <- integer(-100..100),
              offset2 <- integer(-100..100)
            ) do
        i1 = add_offset_iso(offset1)
        i2 = add_offset_iso(offset2)

        composed = Iso.compose(i1, i2)

        # Round-trip forward-back
        result1 = value |> Iso.view(composed) |> then(&Iso.review(&1, composed))
        assert result1 == value

        # Round-trip back-forward
        result2 = value |> Iso.review(composed) |> then(&Iso.view(&1, composed))
        assert result2 == value
      end
    end

    property "list composition applies transformations in sequence" do
      check all(
              value <- integer(),
              offset1 <- integer(-50..50),
              offset2 <- integer(-50..50),
              offset3 <- integer(-50..50)
            ) do
        isos = [
          add_offset_iso(offset1),
          add_offset_iso(offset2),
          add_offset_iso(offset3)
        ]

        composed = Iso.compose(isos)

        # View should apply all offsets in order
        expected_view = value + offset1 + offset2 + offset3
        assert Iso.view(value, composed) == expected_view

        # Round-trip should return original
        result = value |> Iso.view(composed) |> then(&Iso.review(&1, composed))
        assert result == value
      end
    end

    property "empty list composition returns identity" do
      check all(value <- one_of([integer(), string(:alphanumeric)])) do
        composed = Iso.compose([])

        assert Iso.view(value, composed) == value
        assert Iso.review(value, composed) == value
      end
    end
  end
end
