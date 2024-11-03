defmodule Example.User do
  @moduledoc """
  Defines a `User` struct with custom equality (`Eq`) and ordering (`Ord`) implementations
  for functional, domain-driven comparisons.

  In our domain, a `User` is identified primarily by their `first_name` and `last_name`.
  Custom comparison functions are also provided to compare users based on optional
  attributes, such as `age`.
  """

  alias Monex.Maybe
  alias Monex.Eq
  alias Monex.Ord

  @enforce_keys [:first_name, :last_name, :role]
  defstruct first_name: nil,
            last_name: nil,
            age: Maybe.nothing(),
            role: nil

  @type role :: :owner | :admin | :user
  @type t :: %__MODULE__{
          first_name: String.t(),
          last_name: String.t(),
          age: Maybe.t(non_neg_integer()),
          role: role()
        }

  @doc """
  Creates a new `User` struct, accepting a `first_name`, `last_name`, `role`, and optional `age`.

  - If `age` is not provided, it defaults to `Maybe.nothing()`.
  - Uses `Maybe.lift_predicate/2` to wrap `age` as `Just` if it’s a valid integer, otherwise `Nothing`.

  ## Examples

      iex> Example.User.create_user("John", "Doe", :user, 30)
      %Example.User{
        first_name: "John",
        last_name: "Doe",
        age: %Monex.Maybe.Just{value: 30},
        role: :user
      }

      iex> Example.User.create_user("Jane", "Smith", :admin)
      %Example.User{
        first_name: "Jane",
        last_name: "Smith",
        age: %Monex.Maybe.Nothing{},
        role: :admin
      }
  """
  @spec create_user(String.t(), String.t(), role(), integer() | nil) :: t()
  def create_user(first, last, role, age \\ nil) do
    %__MODULE__{
      first_name: first,
      last_name: last,
      age: Maybe.lift_predicate(age, &is_integer/1),
      role: role
    }
  end

  @doc """
  Provides a custom `Eq` comparator for comparing `User`s by `age`.

  This function uses `contramap` to lift equality to the `age` field of each user.

  ## Examples

      iex> eq_age = Example.User.eq_age()
      iex> user1 = Example.User.create_user("Alice", "Smith", :user, 25)
      iex> user2 = Example.User.create_user("Bob", "Brown", :admin, 25)
      iex> Monex.Eq.Utils.equal?(user1, user2, eq_age)
      true
  """
  def eq_age do
    Eq.Utils.contramap(& &1.age)
  end

  @doc """
  Provides a custom `Ord` comparator for ordering `User`s by `age`.

  This function uses `contramap` to lift ordering to the `age` field of each user.

  ## Examples

      iex> ord_age = Example.User.ord_age()
      iex> user1 = Example.User.create_user("Alice", "Smith", :user, 20)
      iex> user2 = Example.User.create_user("Bob", "Brown", :admin, 25)
      iex> Monex.Ord.Utils.min(user1, user2, ord_age)
      %Example.User{first_name: "Alice", last_name: "Smith", age: %Monex.Maybe.Just{value: 20}, role: :user}
  """
  def ord_age do
    Ord.Utils.contramap(& &1.age)
  end
end

defimpl Monex.Eq, for: Example.User do
  @moduledoc false

  @doc """
  Checks if two `User`s are equal by comparing their `first_name` and `last_name`.

  In this domain, two `User`s are considered equal if they share the same `first_name`
  and `last_name`, regardless of other fields.

  ## Examples

      iex> user1 = Example.User.create_user("John", "Doe", :user)
      iex> user2 = Example.User.create_user("John", "Doe", :admin)
      iex> Monex.Eq.Utils.equal?(user1, user2)
      true
  """
  def eq?(%Example.User{first_name: fn1, last_name: ln1}, %Example.User{
        first_name: fn2,
        last_name: ln2
      }) do
    fn1 == fn2 and ln1 == ln2
  end

  def eq?(_, _), do: false

  @doc """
  Returns a default `Eq` implementation for equality comparison.

  This is useful for comparing non-`User` types or using a generic equality check.
  """
  def get_eq(_inner_eq) do
    %{eq?: fn a, b -> a == b end}
  end
end

defimpl Monex.Ord, for: Example.User do
  alias Monex.Ord
  @moduledoc false

  @doc """
  Compares two `User`s for ordering based on `last_name`, and then by `first_name` if
  the last names are the same.

  This ordering allows `User`s to be sorted alphabetically by name.

  ## Examples

      iex> user1 = Example.User.create_user("Alice", "Smith", :user)
      iex> user2 = Example.User.create_user("Bob", "Brown", :admin)
      iex> Monex.Ord.Utils.compare(user1, user2)
      :lt
  """
  def lt?(%Example.User{last_name: ln1, first_name: fn1}, %Example.User{
        last_name: ln2,
        first_name: fn2
      }) do
    ln1 < ln2 or (ln1 == ln2 and fn1 < fn2)
  end

  def le?(a, b), do: not Ord.gt?(a, b)
  def gt?(a, b), do: Ord.lt?(b, a)
  def ge?(a, b), do: not Ord.lt?(a, b)
end
