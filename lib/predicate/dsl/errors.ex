defmodule Funx.Predicate.Dsl.Errors do
  @moduledoc false
  # Centralized error messages for Predicate DSL

  @doc "Error: negate without predicate"
  def negate_without_predicate do
    """
    The `negate` directive requires a predicate.

    Valid:
      negate is_banned
      negate &is_suspended/1

    Invalid:
      negate
    """
  end

  @doc "Error: invalid projection type in check directive"
  def invalid_projection_type(got) do
    """
    Invalid projection type in `check` directive.

    Expected one of:
      - atom                  (e.g., :name)
      - Lens                  (e.g., Lens.key(:name))
      - Prism                 (e.g., Prism.key(:score), Prism.struct(User))
      - Traversal             (e.g., Traversal.combine([...]))
      - function              (e.g., &(&1.field), fn x -> x.value end)

    Got: #{inspect(got)}
    """
  end

  @doc "Error: bare module reference without behaviour"
  def bare_module_without_behaviour(module) do
    """
    Bare module reference #{inspect(module)} does not implement Predicate.Dsl.Behaviour.

    Module atoms are not functions and will cause a BadFunctionError at runtime.

    To fix, choose one of:
      1. Implement the Predicate.Dsl.Behaviour:
         @behaviour Funx.Predicate.Dsl.Behaviour
         def pred(_opts), do: fn value -> ... end

      2. Use tuple syntax to pass options:
         {#{inspect(module)}, []}

      3. Call a function explicitly:
         #{inspect(module)}.my_predicate_function()

      4. Use a variable or captured function instead:
         my_predicate  # where my_predicate is bound to a function
    """
  end
end
