defmodule Monex.Monoid.Ord do
  @moduledoc """
  A monoid implementation for ordering logic (Ord).
  Provides default comparison functions and supports combining multiple
  `Ord` comparators into a single composite comparator.
  """

  @type t :: %__MODULE__{
          lt?: (any(), any() -> boolean()),
          le?: (any(), any() -> boolean()),
          gt?: (any(), any() -> boolean()),
          ge?: (any(), any() -> boolean())
        }

  defstruct lt?: &Monex.Monoid.Ord.default_val?/2,
            le?: &Monex.Monoid.Ord.default_val?/2,
            gt?: &Monex.Monoid.Ord.default_val?/2,
            ge?: &Monex.Monoid.Ord.default_val?/2

  @doc """
  A default comparison function that always returns `true`.
  """
  @spec default_val?(any(), any()) :: boolean()
  def default_val?(_, _), do: true
end

defimpl Monex.Monoid, for: Monex.Monoid.Ord do
  alias Monex.Monoid.Ord

  @spec empty(any()) :: Ord.t()
  def empty(_) do
    %Ord{
      lt?: &Ord.default_val?/2,
      le?: &Ord.default_val?/2,
      gt?: &Ord.default_val?/2,
      ge?: &Ord.default_val?/2
    }
  end

  @spec append(Ord.t(), Ord.t()) :: Ord.t()
  def append(%Ord{} = ord1, %Ord{} = ord2) do
    %Ord{
      lt?: fn a, b -> ord1.lt?.(a, b) or (not ord1.gt?.(a, b) and ord2.lt?.(a, b)) end,
      le?: fn a, b -> ord1.le?.(a, b) or (not ord1.gt?.(a, b) and ord2.le?.(a, b)) end,
      gt?: fn a, b -> ord1.gt?.(a, b) or (not ord1.lt?.(a, b) and ord2.gt?.(a, b)) end,
      ge?: fn a, b -> ord1.ge?.(a, b) or (not ord1.lt?.(a, b) and ord2.ge?.(a, b)) end
    }
  end

  @spec wrap(Ord.t(), map()) :: Ord.t()
  def wrap(%Ord{}, %{lt?: lt?, le?: le?, gt?: gt?, ge?: ge?}) do
    %Ord{lt?: lt?, le?: le?, gt?: gt?, ge?: ge?}
  end

  @spec unwrap(Ord.t()) :: map()
  def unwrap(%Ord{lt?: lt?, le?: le?, gt?: gt?, ge?: ge?}) do
    %{
      lt?: lt?,
      le?: le?,
      gt?: gt?,
      ge?: ge?
    }
  end
end
