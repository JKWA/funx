defmodule Monex.TestCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Monex.TestTelemetryHelper

      defp with_telemetry_config(context) do
        initial_telemetry_enabled = Application.get_env(:monex, :telemetry_enabled, true)
        initial_telemetry_prefix = Application.get_env(:monex, :telemetry_prefix, [:monex])

        ExUnit.Callbacks.on_exit(fn ->
          Application.put_env(:monex, :telemetry_enabled, initial_telemetry_enabled)
          Application.put_env(:monex, :telemetry_prefix, initial_telemetry_prefix)
        end)

        {:ok, context}
      end
    end
  end
end
