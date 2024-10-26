defmodule Monex.Effect.Right do
  @enforce_keys [:effect]
  defstruct [:effect]

  @type t(right) :: %__MODULE__{effect: (-> Task.t(%Monex.Either.Right{value: right}))}

  @spec pure(right) :: t(right) when right: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Monex.Either.Right{value: value} end) end
    }
  end

  defimpl Monex.Monad do
    alias Monex.Effect
    alias Effect.{Right, Left}

    alias Monex.Either

    @spec ap(Right.t((right -> result)), Effect.t(left, right)) ::
            Effect.t(left, result)
          when left: term(), right: term(), result: term()
    def ap(%Right{effect: effect_func}, %Right{effect: effect_value}) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            %Either.Right{value: func} = Task.await(effect_func.())
            %Either.Right{value: value} = Task.await(effect_value.())
            %Either.Right{value: func.(value)}
          end)
        end
      }
    end

    def ap(_, %Left{} = left), do: left

    @spec bind(Right.t(right), (right -> Effect.t(left, result))) ::
            Effect.t(left, result)
          when left: term(), right: term(), result: term()
    def bind(%Right{effect: effect}, binder) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            case Task.await(effect.()) do
              %Monex.Either.Right{value: value} ->
                case binder.(value) do
                  %Right{effect: next_effect} -> Task.await(next_effect.())
                  %Left{effect: next_effect} -> Task.await(next_effect.())
                end

              %Either.Left{value: left_value} ->
                %Either.Left{value: left_value}
            end
          end)
        end
      }
    end

    @spec map(Right.t(right), (right -> result)) :: Right.t(result)
          when right: term(), result: term()
    def map(%Right{effect: effect}, mapper) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            case Task.await(effect.()) do
              %Either.Right{value: value} ->
                %Either.Right{value: mapper.(value)}

              %Either.Left{value: error} ->
                %Either.Left{value: error}
            end
          end)
        end
      }
    end
  end

  defimpl String.Chars do
    alias Monex.Effect.Right

    def to_string(%Right{effect: effect}) do
      "Right(#{Task.await(effect.())})"
    end
  end
end
