ExUnit.start()

Path.wildcard("test/support/**/*.exs")
|> Enum.each(&Code.require_file/1)

defmodule Monex.MacrosTest.Person do
  require Monex.Macros

  @moduledoc """
  A simple struct representing a person.
  """
  defstruct [:name, :age]
  Monex.Macros.ord_for(Monex.MacrosTest.Person, :age)
  Monex.Macros.eq_for(Monex.MacrosTest.Person, :age)
end
