defmodule Funx.Monad.Writer.Result do
  @moduledoc """
  Represents the result of running a Writer computation:
  the final value and the accumulated monoid.
  """

  defstruct [:value, :log]

  @type t(a, l) :: %__MODULE__{
          value: a,
          log: l
        }
end
