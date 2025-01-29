# credo:disable-for-this-file

defmodule Monex.Monoid.Eq.All do
  @moduledoc """
  A Monoid implementation for equality checks for All.
  """
  defstruct eq?: &Monex.Monoid.Eq.All.default_eq?/2,
            not_eq?: &Monex.Monoid.Eq.All.default_not_eq?/2

  def default_eq?(_, _), do: true

  def default_not_eq?(_, _), do: false
end

defimpl Monex.Monoid, for: Monex.Monoid.Eq.All do
  alias Monex.Monoid.Eq.All

  def empty(_), do: %All{}

  def append(%All{} = eq1, %All{} = eq2) do
    %All{
      eq?: fn a, b -> eq1.eq?.(a, b) and eq2.eq?.(a, b) end,
      not_eq?: fn a, b -> eq1.not_eq?.(a, b) or eq2.not_eq?.(a, b) end
    }
  end

  def wrap(%All{}, %{eq?: eq?, not_eq?: not_eq?}) do
    %All{eq?: eq?, not_eq?: not_eq?}
  end

  def wrap(%All{}, eq) when is_atom(eq) do
    %All{
      eq?: &eq.eq?/2,
      not_eq?: &eq.not_eq?/2
    }
  end

  def unwrap(%All{eq?: eq?, not_eq?: not_eq?}) do
    %{eq?: eq?, not_eq?: not_eq?}
  end
end
