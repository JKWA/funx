defmodule Funx.Predicate.NotEq do
  @moduledoc """
  Predicate that checks if a value does not equal an expected value using an
  `Eq` comparator.

  Options

  - `:value` (required)
    The value to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  ## Examples

      use Funx.Predicate

      # Check that status is not deleted
      pred do
        check :status, {NotEq, value: :deleted}
      end

      # Check that struct is not a specific error type
      pred do
        check :error, {NotEq, value: FatalError}
      end

      # With custom Eq comparator
      pred do
        check :amount, {NotEq, value: zero, eq: Money.Eq}
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
          mod != expected

        _ ->
          Eq.not_eq?(value, expected, eq)
      end
    end
  end
end
