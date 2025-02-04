defmodule Monex.Predicate do
  @moduledoc """
  The `Monex.Predicate` module provides utility functions for working with predicates.
  Predicates are functions that return a boolean (`true` or `false`), and this module allows you to combine them using logical operations.

  You can combine multiple predicates into a single function using:
  - `p_and/2`: Combines two predicates using logical AND.
  - `p_or/2`: Combines two predicates using logical OR.
  - `p_not/1`: Negates a predicate.

  These functions are useful for building complex conditional logic in a functional and composable way.

  ## Examples

  ### Using `p_and/2` to combine predicates:

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

  ### Using `p_not/1` to negate a condition:

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Monex.Predicate.p_not(is_minor)
      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false
  """
  import Monex.Monoid.Utils, only: [append: 3, concat: 2]
  alias Monex.Monoid.Predicate.{All, Any}

  defstruct predicate: nil

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical AND.
  Returns a new predicate that returns `true` only if both `pred1` and `pred2` return `true`.

  ## Examples

      iex> is_adult = fn person -> person.age >= 18 end
      iex> has_ticket = fn person -> person.tickets > 0 end
      iex> can_enter = Monex.Predicate.p_and(is_adult, has_ticket)
      iex> can_enter.(%{age: 20, tickets: 1})
      true
      iex> can_enter.(%{age: 16, tickets: 1})
      false
  """
  def p_and(pred1, pred2) do
    fn value -> pred1.(value) and pred2.(value) end
  end

  @doc """
  Combines two predicates (`pred1` and `pred2`) using logical OR.
  Returns a new predicate that returns `true` if either `pred1` or `pred2` returns `true`.

  ## Examples

      iex> is_vip = fn person -> person.vip end
      iex> is_sponsor = fn person -> person.sponsor end
      iex> can_access_vip_area = Monex.Predicate.p_or(is_vip, is_sponsor)
      iex> can_access_vip_area.(%{vip: true, sponsor: false})
      true
      iex> can_access_vip_area.(%{vip: false, sponsor: false})
      false
  """
  def p_or(pred1, pred2) do
    fn value -> pred1.(value) or pred2.(value) end
  end

  @doc """
  Negates a predicate (`pred`).
  Returns a new predicate that returns `true` if `pred` returns `false`, and vice versa.

  ## Examples

      iex> is_minor = fn person -> person.age < 18 end
      iex> is_adult = Monex.Predicate.p_not(is_minor)
      iex> is_adult.(%{age: 20})
      true
      iex> is_adult.(%{age: 16})
      false
  """
  def p_not(pred) do
    fn value -> not pred.(value) end
  end

  def p_all(a, b) do
    append(%All{}, a, b)
  end

  def p_all(p_list) when is_list(p_list) do
    concat(%All{}, p_list)
  end

  def p_any(a, b) do
    append(%Any{}, a, b)
  end

  def p_any(p_list) when is_list(p_list) do
    concat(%Any{}, p_list)
  end

  def p_none(a, b) do
    p_not(p_any(a, b))
  end

  def p_none(p_list) when is_list(p_list) do
    p_not(p_any(p_list))
  end
end
