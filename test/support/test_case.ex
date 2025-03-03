defmodule Funx.TestCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Funx.TestTelemetryHelper

      defp with_telemetry_config(context) do
        initial_telemetry_enabled = Application.get_env(:funx, :telemetry_enabled, true)
        initial_telemetry_prefix = Application.get_env(:funx, :telemetry_prefix, [:funx])

        ExUnit.Callbacks.on_exit(fn ->
          Application.put_env(:funx, :telemetry_enabled, initial_telemetry_enabled)
          Application.put_env(:funx, :telemetry_prefix, initial_telemetry_prefix)
        end)

        {:ok, context}
      end
    end
  end
end
