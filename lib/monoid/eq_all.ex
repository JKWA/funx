# credo:disable-for-this-file

defmodule Funx.Monoid.Eq.All do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Feq_all.livemd)

  A Monoid implementation for equality checks for All.
  """

  @type t :: %__MODULE__{
          eq?: (any(), any() -> boolean()),
          not_eq?: (any(), any() -> boolean())
        }

  defstruct eq?: &Funx.Monoid.Eq.All.default_eq?/2,
            not_eq?: &Funx.Monoid.Eq.All.default_not_eq?/2

  def default_eq?(_, _), do: true

  def default_not_eq?(_, _), do: false
end

defimpl Funx.Monoid, for: Funx.Monoid.Eq.All do
  alias Funx.Monoid.Eq.All

  def empty(_), do: %All{}

  def append(%All{} = eq1, %All{} = eq2) do
    %All{
      eq?: fn a, b -> eq1.eq?.(a, b) && eq2.eq?.(a, b) end,
      not_eq?: fn a, b -> eq1.not_eq?.(a, b) || eq2.not_eq?.(a, b) end
    }
  end

  def wrap(%All{}, eq) do
    eq = Funx.Eq.to_eq_map(eq)

    %All{
      eq?: eq.eq?,
      not_eq?: eq.not_eq?
    }
  end

  def unwrap(%All{eq?: eq?, not_eq?: not_eq?}) do
    %{eq?: eq?, not_eq?: not_eq?}
  end
end
