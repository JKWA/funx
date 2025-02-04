defmodule Monex.Predicate do
  @moduledoc """
  Provides utility functions for working with predicates—functions that return `true` or `false`.

  This module enables combining predicates in a declarative way using logical operations:

  - `p_and/2`: Returns `true` if **both** predicates are `true`.
  - `p_or/2`: Returns `true` if **at least one** predicate is `true`.
  - `p_not/1`: Negates a predicate.
  - `p_all/1`: Returns `true` if **all** predicates in a list are `true`.
  - `p_any/1`: Returns `true` if **any** predicate in a list is `true`.
  - `p_none/1`: Returns `true` if **none** of the predicates in a list are `true`.

  These functions simplify complex conditional logic.

  ## Examples

  ### Combining predicates with `p_and/2`:

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Monex.Predicate.p_and(is_adult, has_ticket)

      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false

  ### Using `p_or/2` for alternative conditions:

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Monex.Predicate.p_or(is_vip, is_sponsor)

      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false

  ### Negating predicates with `p_not/1`:

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Monex.Predicate.p_not(is_minor)

      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false

  ### Using `p_all/1` and `p_any/1` for predicate lists:

      iex> conditions = [is_adult, has_ticket]
      iex> must_meet_all = Monex.Predicate.p_all(conditions)
      iex> must_meet_any = Monex.Predicate.p_any(conditions)

      iex> must_meet_all.(%{age: 20, tickets: 1})
      true
      iex> must_meet_all.(%{age: 20, tickets: 0})
      false

      iex> must_meet_any.(%{age: 20, tickets: 0})
      true
      iex> must_meet_any.(%{age: 16, tickets: 0})
      false

  ### Using `p_none/1` to reject multiple conditions:

      iex> cannot_enter = Monex.Predicate.p_none([is_adult, is_vip])

      iex> cannot_enter.(%{age: 20, ticket: :vip})
      false
      iex> cannot_enter.(%{age: 16, ticket: :basic})
      true
  """
  import Monex.Monoid.Utils, only: [append: 3, concat: 2]
  alias Monex.Monoid.Predicate.{All, Any}

  @type t() :: (term() -> boolean())

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical AND.
  Returns a predicate that evaluates to `true` only if both `pred1` and `pred2` return `true`.

  ## Examples

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Monex.Predicate.p_and(is_adult, has_ticket)

      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false
  """
  @spec p_and(t(), t()) :: t()
  def p_and(pred1, pred2) when is_function(pred1) and is_function(pred2) do
    append(%All{}, pred1, pred2)
  end

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical OR.
  Returns a predicate that evaluates to `true` if either `pred1` or `pred2` return `true`.

  ## Examples

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Monex.Predicate.p_or(is_vip, is_sponsor)

      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false
  """
  @spec p_or(t(), t()) :: t()
  def p_or(pred1, pred2) when is_function(pred1) and is_function(pred2) do
    append(%Any{}, pred1, pred2)
  end

  @doc """
  Negates a predicate (`pred`).
  Returns a predicate that evaluates to `true` when `pred` returns `false`, and vice versa.

  ## Examples

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Monex.Predicate.p_not(is_minor)

      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false
  """
  @spec p_not(t()) :: t()
  def p_not(pred) when is_function(pred) do
    fn value -> not pred.(value) end
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical AND.
  Returns `true` only if all predicates return `true`. An empty list returns `true`.

  ## Examples

      iex> can_enter = Monex.Predicate.p_all([is_adult, has_ticket])

      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false
  """
  @spec p_all([t()]) :: t()
  def p_all(p_list) when is_list(p_list) do
    concat(%All{}, p_list)
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical OR.
  Returns `true` if at least one predicate returns `true`. An empty list returns `false`.

  ## Examples

      iex> can_access_vip_area = Monex.Predicate.p_any([is_vip, is_sponsor])

      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false
  """
  @spec p_any([t()]) :: t()
  def p_any(p_list) when is_list(p_list) do
    concat(%Any{}, p_list)
  end

  @doc """
  Combines a list of predicates (`p_list`) using logical NOR (negated OR).
  Returns `true` only if **none** of the predicates return `true`. An empty list returns `true`.

  ## Examples

      iex> cannot_enter = Monex.Predicate.p_none([is_adult, is_vip])

      iex> cannot_enter.(%{age: 20, ticket: :vip})
      false
      iex> cannot_enter.(%{age: 16, ticket: :basic})
      true
  """
  @spec p_none([t()]) :: t()
  def p_none(p_list) when is_list(p_list) do
    p_not(p_any(p_list))
  end
end
