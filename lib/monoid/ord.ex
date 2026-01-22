# credo:disable-for-this-file

defmodule Funx.Monoid.Ord do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Ford.livemd)

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

  defstruct lt?: &Funx.Monoid.Ord.default?/2,
            le?: &Funx.Monoid.Ord.default?/2,
            gt?: &Funx.Monoid.Ord.default?/2,
            ge?: &Funx.Monoid.Ord.default?/2

  def default?(_, _), do: false
end

defimpl Funx.Monoid, for: Funx.Monoid.Ord do
  alias Funx.Monoid.Ord

  @spec empty(any()) :: Ord.t()
  def empty(_) do
    %Ord{}
  end

  @spec append(Ord.t(), Ord.t()) :: Ord.t()
  def append(%Ord{} = ord1, %Ord{} = ord2) do
    %Ord{
      lt?: fn a, b ->
        cond do
          ord1.lt?.(a, b) -> true
          ord1.gt?.(a, b) -> false
          true -> ord2.lt?.(a, b)
        end
      end,
      le?: fn a, b ->
        cond do
          ord1.lt?.(a, b) -> true
          ord1.gt?.(a, b) -> false
          true -> ord2.le?.(a, b)
        end
      end,
      gt?: fn a, b ->
        cond do
          ord1.gt?.(a, b) -> true
          ord1.lt?.(a, b) -> false
          true -> ord2.gt?.(a, b)
        end
      end,
      ge?: fn a, b ->
        cond do
          ord1.gt?.(a, b) -> true
          ord1.lt?.(a, b) -> false
          true -> ord2.ge?.(a, b)
        end
      end
    }
  end

  def wrap(%Ord{}, ord) do
    ord = Funx.Ord.to_ord_map(ord)

    %Ord{
      lt?: ord.lt?,
      le?: ord.le?,
      gt?: ord.gt?,
      ge?: ord.ge?
    }
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
