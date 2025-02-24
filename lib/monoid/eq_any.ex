# credo:disable-for-this-file

defmodule Monex.Monoid.Eq.Any do
  @moduledoc """
  A Monoid implementation for equality checks for Any.
  """

  defstruct eq?: &Monex.Monoid.Eq.Any.default_eq?/2,
            not_eq?: &Monex.Monoid.Eq.Any.default_not_eq?/2

  def default_eq?(_, _), do: false

  def default_not_eq?(_, _), do: true
end

defimpl Monex.Monoid, for: Monex.Monoid.Eq.Any do
  alias Monex.Monoid.Eq.Any

  def empty(_), do: %Any{}

  def append(%Any{} = eq1, %Any{} = eq2) do
    %Any{
      eq?: fn a, b -> eq1.eq?.(a, b) || eq2.eq?.(a, b) end,
      not_eq?: fn a, b -> eq1.not_eq?.(a, b) && eq2.not_eq?.(a, b) end
    }
  end

  def wrap(%Any{}, %{eq?: eq?, not_eq?: not_eq?}) do
    %Any{eq?: eq?, not_eq?: not_eq?}
  end

  def wrap(%Any{}, eq) when is_atom(eq) do
    %Any{
      eq?: &eq.eq?/2,
      not_eq?: &eq.not_eq?/2
    }
  end

  def unwrap(%Any{eq?: eq?, not_eq?: not_eq?}) do
    %{eq?: eq?, not_eq?: not_eq?}
  end
end
