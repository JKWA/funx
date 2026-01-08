defmodule Funx.Validate.Dsl.Parser do
  @moduledoc false
  # Compile-time parser that converts Validation DSL syntax into Step nodes.
  #
  # ## Syntax Recognition
  #
  # The parser recognizes these forms:
  #
  #   - Bare validator                        → Step{optic: nil, validators: [validator]}
  #   - at :key, validator                    → Step{optic: :key, validators: [validator]}
  #   - at :key, [v1, v2]                     → Step{optic: :key, validators: [v1, v2]}
  #   - at Lens.key(:key), validator          → Step{optic: Lens, validators: [validator]}
  #   - at Prism.key(:key), validator         → Step{optic: Prism, validators: [validator]}
  #
  # ## Validator Specs
  #
  #   - Module: Required
  #   - Tuple: {MinLength, min: 3}
  #   - List: [Required, {MinLength, min: 3}, Email]

  alias Funx.Optics.Prism
  alias Funx.Validate.Dsl.Step

  @doc """
  Parse a DSL block into a list of Step nodes.
  """
  def parse_steps(block, caller_env) do
    block
    |> extract_statements()
    |> Enum.map(&parse_statement(&1, caller_env))
  end

  defp extract_statements({:__block__, _meta, statements}) when is_list(statements) do
    statements
  end

  defp extract_statements(single_statement), do: [single_statement]

  # Parse "at optic_or_key, validator_spec"
  defp parse_statement({:at, meta, [optic_or_key, validator_spec]}, _caller_env) do
    optic = normalize_optic(optic_or_key)
    metadata = extract_meta(meta)
    Step.new_projected(optic, validator_spec, metadata)
  end

  # Parse bare validator (root validator)
  defp parse_statement(validator_spec, _caller_env) do
    Step.new_root(validator_spec, %{})
  end

  # Normalize optic expressions
  # Atom keys default to Prism
  defp normalize_optic(key) when is_atom(key) do
    quote do
      Prism.key(unquote(key))
    end
  end

  # Explicit optic expression (Lens.key(:x), Prism.key(:x), etc.)
  defp normalize_optic(optic_expr), do: optic_expr

  defp extract_meta(meta) do
    %{
      line: Keyword.get(meta, :line)
    }
  end
end
