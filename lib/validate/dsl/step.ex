defmodule Funx.Validate.Dsl.Step do
  @moduledoc false
  # Represents a single validation step in the Validation DSL.
  #
  # ## Structure
  #
  # A Step can be:
  #   - Root validator: Validates the entire structure
  #   - Projected validator: Validates a field via optic projection
  #
  # ## Examples
  #
  # Root validator:
  #   HasContactMethod
  #
  # Projected validator:
  #   at :name, Required
  #   at :email, [Required, Email]
  #   at Lens.key(:age), Positive

  # Lens.t() | Prism.t() | Traversal.t() | atom()
  @type optic :: term()
  @type validator_spec ::
          module() | {module(), keyword()} | list(module() | {module(), keyword()})

  @type t :: %__MODULE__{
          optic: optic() | nil,
          validators: list(validator_spec()),
          __meta__: map()
        }

  defstruct [:optic, :validators, :__meta__]

  @doc """
  Creates a root validation step (no projection).
  """
  @spec new_root(validator_spec(), map()) :: t()
  def new_root(validator_spec, meta \\ %{}) do
    %__MODULE__{
      optic: nil,
      validators: normalize_validators(validator_spec),
      __meta__: meta
    }
  end

  @doc """
  Creates a projected validation step.
  """
  @spec new_projected(optic(), validator_spec(), map()) :: t()
  def new_projected(optic, validator_spec, meta \\ %{}) do
    %__MODULE__{
      optic: optic,
      validators: normalize_validators(validator_spec),
      __meta__: meta
    }
  end

  # Normalizes validator specs into a list
  defp normalize_validators(spec) when is_list(spec), do: spec
  defp normalize_validators(spec), do: [spec]
end
