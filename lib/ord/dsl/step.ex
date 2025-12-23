defmodule Funx.Ord.Dsl.Step do
  @moduledoc false

  @type direction :: :asc | :desc
  @type projection :: Macro.t()
  @type ord :: module() | Macro.t()

  @type t :: %__MODULE__{
          direction: direction(),
          projection: projection(),
          ord: ord(),
          __meta__: map()
        }

  defstruct [:direction, :projection, :ord, :__meta__]

  @doc """
  Creates a new step with the given direction, projection AST, ord module, and metadata.
  """
  @spec new(direction(), projection(), ord(), map()) :: t()
  def new(direction, projection, ord, meta \\ %{}) do
    %__MODULE__{
      direction: direction,
      projection: projection,
      ord: ord,
      __meta__: meta
    }
  end
end
