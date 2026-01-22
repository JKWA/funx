defmodule Funx.Monad.Writer.Result do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fwriter%2Fresult.livemd)

  Represents the result of running a Writer computation:
  the final value and the accumulated monoid.
  """

  defstruct [:value, :log]

  @type t(a, l) :: %__MODULE__{
          value: a,
          log: l
        }
end
