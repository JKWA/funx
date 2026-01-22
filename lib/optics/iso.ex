defmodule Funx.Optics.Iso do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Foptics%2Fiso.livemd)

  The `Funx.Optics.Iso` module provides a lawful isomorphism optic for bidirectional, lossless transformations.

  An isomorphism (iso) represents a reversible transformation between two types. It consists of
  two inverse functions that satisfy the round-trip laws:

  - `review(view(s, iso), iso) == s` - Round-trip forward then back returns the original
  - `view(review(a, iso), iso) == a` - Round-trip back then forward returns the original

  Isos are total optics with no partiality. If the transformation can fail, you do not have an iso.
  Contract violations crash immediately - there are no bang variants or safe alternatives.

  ### Constructors

    - `make/2`: Creates a custom iso from two inverse functions.
    - `identity/0`: The identity iso (both directions are identity).

  ### Core Operations

    - `view/2`: Apply the forward transformation (s -> a).
    - `review/2`: Apply the backward transformation (a -> s).
    - `over/3`: Modify the viewed side (view, apply function, review).
    - `under/3`: Modify the reviewed side (review, apply function, view).

  ### Direction

    - `from/1`: Reverse the iso's direction.

  ### Composition

    - `compose/2`: Composes two isos sequentially (outer then inner).
    - `compose/1`: Composes a list of isos into a single iso.

  ### Interoperability

    - `as_lens/1`: Converts an iso to a lens.
    - `as_prism/1`: Converts an iso to a prism.

  An iso is more powerful than both lens and prism. Every iso can be used as a lens
  (viewing and setting always succeed) or as a prism (preview always returns `Just`).

  Isos compose naturally. Composing two isos yields a new iso where:
  - Forward (`view`) applies the outer iso first, then the inner iso
  - Backward (`review`) applies the inner iso first, then the outer iso

  ## Monoid Structure

  Isos form a monoid under composition.

  The monoid structure is provided via `Funx.Monoid.Optics.IsoCompose`, which wraps isos
  for use with generic monoid operations:

    - **Identity**: `identity/0` - the identity iso
    - **Operation**: `compose/2` - sequential composition

  Composing an empty list returns the identity iso.

  ## Examples

  Simple encoding/decoding:

      iex> alias Funx.Optics.Iso
      iex> # Iso between string and integer (string representation)
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Iso.view("42", string_int)
      42
      iex> Iso.review(42, string_int)
      "42"

  Composing isos:

      iex> alias Funx.Optics.Iso
      iex> # Iso: string <-> integer
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> # Iso: integer <-> doubled integer
      iex> double = Iso.make(
      ...>   fn i -> i * 2 end,
      ...>   fn i -> div(i, 2) end
      ...> )
      iex> # Composed: string <-> doubled integer
      iex> composed = Iso.compose(string_int, double)
      iex> Iso.view("21", composed)
      42
      iex> Iso.review(42, composed)
      "21"

  Using `over` and `under`:

      iex> alias Funx.Optics.Iso
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Iso.over("10", string_int, fn i -> i * 5 end)
      "50"
      iex> Iso.under(100, string_int, fn s -> s <> "0" end)
      1000
  """

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Monad.Maybe
  alias Funx.Monoid.Optics.IsoCompose
  alias Funx.Optics.{Lens, Prism}

  @type forward(s, a) :: (s -> a)
  @type backward(a, s) :: (a -> s)

  @type t(s, a) :: %__MODULE__{
          view: forward(s, a),
          review: backward(a, s)
        }

  @type t :: t(any, any)

  defstruct [:view, :review]

  # ============================================================================
  # Constructors
  # ============================================================================

  @doc """
  Creates a custom iso from two inverse functions.

  The viewer function transforms from the source type to the target type.
  The reviewer function transforms from the target type back to the source type.

  Both functions must be inverses for the iso to be lawful:
  - `review(view(s, iso), iso) == s`
  - `view(review(a, iso), iso) == a`

  If these functions are not true inverses, the iso contract is violated and
  the program is incorrect. There are no runtime checks - the contract is enforced
  by design.

  ## Examples

      iex> # Celsius <-> Fahrenheit
      iex> temp_iso = Funx.Optics.Iso.make(
      ...>   fn c -> c * 9 / 5 + 32 end,
      ...>   fn f -> (f - 32) * 5 / 9 end
      ...> )
      iex> Funx.Optics.Iso.view(0, temp_iso)
      32.0
      iex> Funx.Optics.Iso.review(32, temp_iso)
      0.0
  """
  @spec make(forward(s, a), backward(a, s)) :: t(s, a)
        when s: term(), a: term()
  def make(viewer, reviewer)
      when is_function(viewer, 1) and is_function(reviewer, 1) do
    %__MODULE__{view: viewer, review: reviewer}
  end

  @doc """
  The identity iso that leaves values unchanged in both directions.

  ## Examples

      iex> iso = Funx.Optics.Iso.identity()
      iex> Funx.Optics.Iso.view(42, iso)
      42
      iex> Funx.Optics.Iso.review(42, iso)
      42
  """
  @spec identity() :: t()
  def identity do
    make(
      fn x -> x end,
      fn x -> x end
    )
  end

  # ============================================================================
  # Core Operations
  # ============================================================================

  @doc """
  Apply the forward transformation of the iso.

  Transforms from the source type to the target type.

  This operation is total. If it crashes, the iso contract is violated.

  ## Examples

      iex> string_int = Funx.Optics.Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Funx.Optics.Iso.view("42", string_int)
      42
  """
  @spec view(s, t(s, a)) :: a
        when s: term(), a: term()
  def view(s, %__MODULE__{view: v}), do: v.(s)

  @doc """
  Apply the backward transformation of the iso.

  Transforms from the target type back to the source type.

  This operation is total. If it crashes, the iso contract is violated.

  ## Examples

      iex> string_int = Funx.Optics.Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Funx.Optics.Iso.review(42, string_int)
      "42"
  """
  @spec review(a, t(s, a)) :: s
        when s: term(), a: term()
  def review(a, %__MODULE__{review: r}), do: r.(a)

  @doc """
  Modify the viewed side of the iso.

  Applies a function through the iso: view, apply function, review.

  This is the standard optic modifier, consistent with Lens and Prism.

  ## Examples

      iex> string_int = Funx.Optics.Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Funx.Optics.Iso.over("10", string_int, fn i -> i * 5 end)
      "50"
  """
  @spec over(s, t(s, a), (a -> a)) :: s
        when s: term(), a: term()
  def over(s, %__MODULE__{} = iso, f) when is_function(f, 1) do
    s |> view(iso) |> f.() |> then(&review(&1, iso))
  end

  @doc """
  Modify the reviewed side of the iso.

  Applies a function in reverse through the iso: review, apply function, view.

  This operation is unique to Iso due to its bidirectional symmetry.
  Lens and Prism cannot offer this.

  ## Examples

      iex> string_int = Funx.Optics.Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> Funx.Optics.Iso.under(100, string_int, fn s -> s <> "0" end)
      1000
  """
  @spec under(a, t(s, a), (s -> s)) :: a
        when s: term(), a: term()
  def under(a, %__MODULE__{} = iso, f) when is_function(f, 1) do
    a |> review(iso) |> f.() |> then(&view(&1, iso))
  end

  # ============================================================================
  # Direction
  # ============================================================================

  @doc """
  Reverses the direction of an iso.

  Swaps the view and review functions.

  This is the established optic operation for reversing direction, following Haskell's
  `Control.Lens.Iso.from`.

  ## Examples

      iex> string_int = Funx.Optics.Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> int_string = Funx.Optics.Iso.from(string_int)
      iex> Funx.Optics.Iso.view(42, int_string)
      "42"
      iex> Funx.Optics.Iso.review("42", int_string)
      42
  """
  @spec from(t(s, a)) :: t(a, s)
        when s: term(), a: term()
  def from(%__MODULE__{view: v, review: r}) do
    make(r, v)
  end

  # ============================================================================
  # Composition
  # ============================================================================

  @doc """
  Composes isos into a single iso using sequential composition.

  This delegates to the monoid append operation, which contains the
  canonical composition logic.

  ## Binary composition

  Composes two isos. The outer iso transforms first, then the inner iso
  transforms the result.

  This is left-to-right composition: the first parameter is applied first.
  This differs from mathematical function composition (f ∘ g applies g first).

  **Sequential semantics:**
  - On `view`: Applies outer's forward transformation first, then inner's forward transformation
  - On `review`: Applies inner's backward transformation first, then outer's backward transformation

  This is sequential transformation through composed isos.

      iex> alias Funx.Optics.Iso
      iex> # string <-> int
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> # int <-> doubled int
      iex> double = Iso.make(
      ...>   fn i -> i * 2 end,
      ...>   fn i -> div(i, 2) end
      ...> )
      iex> composed = Iso.compose(string_int, double)
      iex> Iso.view("21", composed)
      42
      iex> Iso.review(42, composed)
      "21"

  ## List composition

  Composes a list of isos into a single iso using sequential composition.

  **Sequential semantics:**
  - On `view`: Applies transformations in list order (left-to-right)
  - On `review`: Applies transformations in reverse list order (right-to-left)

  This is sequential transformation through composed isos.

      iex> isos = [
      ...>   Funx.Optics.Iso.make(
      ...>     fn s -> String.to_integer(s) end,
      ...>     fn i -> Integer.to_string(i) end
      ...>   ),
      ...>   Funx.Optics.Iso.make(
      ...>     fn i -> i * 2 end,
      ...>     fn i -> div(i, 2) end
      ...>   )
      ...> ]
      iex> composed = Funx.Optics.Iso.compose(isos)
      iex> Funx.Optics.Iso.view("21", composed)
      42
  """
  @spec compose(t(s, i), t(i, a)) :: t(s, a)
        when s: term(), i: term(), a: term()
  def compose(%__MODULE__{} = outer, %__MODULE__{} = inner) do
    m_append(%IsoCompose{}, outer, inner)
  end

  @spec compose([t()]) :: t()
  def compose(isos) when is_list(isos) do
    m_concat(%IsoCompose{}, isos)
  end

  # ============================================================================
  # Interoperability
  # ============================================================================

  @doc """
  Converts an iso to a lens.

  An iso is more powerful than a lens: it provides bidirectional transformation,
  while a lens only provides viewing and updating. Every iso can be used as a lens.

  The resulting lens:
  - `view` uses the iso's forward transformation
  - `update` ignores the old value and uses the iso's backward transformation

  This is safe because an iso is total - the transformation always succeeds.

  ## Examples

      iex> alias Funx.Optics.{Iso, Lens}
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> lens = Iso.as_lens(string_int)
      iex> Lens.view!("42", lens)
      42
      iex> Lens.set!("10", lens, 99)
      "99"
  """
  @spec as_lens(t(s, a)) :: Lens.t(s, a)
        when s: term(), a: term()
  def as_lens(%__MODULE__{view: v, review: r}) do
    Lens.make(
      v,
      fn _s, a -> r.(a) end
    )
  end

  @doc """
  Converts an iso to a prism.

  An iso is more powerful than a prism: it never fails to extract a value,
  while a prism models optional extraction. Every iso can be used as a prism.

  The resulting prism:
  - `preview` always succeeds (returns `Just`), using the iso's forward transformation
  - `review` uses the iso's backward transformation

  This is safe because an iso is total - the transformation always succeeds.

  ## Examples

      iex> alias Funx.Optics.{Iso, Prism}
      iex> alias Funx.Monad.Maybe.Just
      iex> string_int = Iso.make(
      ...>   fn s -> String.to_integer(s) end,
      ...>   fn i -> Integer.to_string(i) end
      ...> )
      iex> prism = Iso.as_prism(string_int)
      iex> Prism.preview("42", prism)
      %Just{value: 42}
      iex> Prism.review(42, prism)
      "42"
  """
  @spec as_prism(t(s, a)) :: Prism.t(s, a)
        when s: term(), a: term()
  def as_prism(%__MODULE__{view: v, review: r}) do
    Prism.make(
      fn s -> Maybe.just(v.(s)) end,
      r
    )
  end
end
