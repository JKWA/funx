ExUnit.start()

Path.wildcard("test/support/**/*.exs")
|> Enum.each(&Code.require_file/1)

defmodule Monex.Test.Person do
  require Monex.Macros

  @moduledoc """
  A simple struct representing a person.
  """
  defstruct name: "UNKNOWN", age: 0, ticket: :basic

  Monex.Macros.ord_for(Monex.Test.Person, :name)
  Monex.Macros.eq_for(Monex.Test.Person, :name)
end
