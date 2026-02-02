defmodule Funx.Predicate.Eq do
  @moduledoc """
  Predicate that checks if a value equals an expected value using an `Eq`
  comparator.

  Options

  - `:value` (required)
    The expected value to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  ## Examples

      use Funx.Predicate

      # Check for specific value
      pred do
        check [:status], {Eq, value: :active}
      end

      # Check for struct type
      pred do
        check [:error], {Eq, value: CustomError}
      end

      # With custom Eq comparator
      pred do
        check [:amount], {Eq, value: expected, eq: Money.Eq}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  alias Funx.Eq

  @impl true
  def pred(opts) do
    expected = Keyword.fetch!(opts, :value)
    eq = Keyword.get(opts, :eq, Eq.Protocol)
    expected_is_module = is_atom(expected)

    fn value ->
      case {value, expected_is_module} do
        {%{__struct__: mod}, true} ->
          mod == expected

        _ ->
          Eq.eq?(value, expected, eq)
      end
    end
  end
end
