defmodule Monex.Effect.Left do
  @enforce_keys [:effect]
  defstruct [:effect]

  @type t(left) :: %__MODULE__{effect: (-> Task.t(%Monex.Either.Left{value: left}))}

  @spec pure(left) :: t(left) when left: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Monex.Either.Left{value: value} end) end
    }
  end

  defimpl Monex.Monad do
    alias Monex.Effect.Left

    @spec bind(Left.t(left), (any() -> Monex.Effect.t(left, result))) :: Left.t(left)
          when left: term(), result: term()
    def bind(%Left{effect: effect}, _binder) do
      %Left{
        effect: fn ->
          Task.async(fn ->
            Task.await(effect.())
          end)
        end
      }
    end

    @spec map(Left.t(left), (right -> result)) :: Left.t(left)
          when left: term(), right: term(), result: term()
    def map(%Left{effect: effect}, _mapper) do
      %Left{effect: effect}
    end

    @spec ap(Left.t(left), Monex.Effect.t(left, right)) :: Left.t(left)
          when left: term(), right: term()
    def ap(%Left{} = left, _), do: left
  end

  defimpl String.Chars do
    alias Monex.Effect.Left

    def to_string(%Left{effect: effect}) do
      "Left(#{Task.await(effect.())})"
    end
  end
end
