ExUnit.start()

Path.wildcard("test/support/**/*.exs")
|> Enum.each(&Code.require_file/1)

defmodule Funx.Test.Person do
  require Funx.Macros

  @moduledoc """
  A simple struct representing a person.
  """
  defstruct name: "UNKNOWN", age: 0, ticket: :basic

  Funx.Macros.ord_for(Funx.Test.Person, :name)
  Funx.Macros.eq_for(Funx.Test.Person, :name)
end
