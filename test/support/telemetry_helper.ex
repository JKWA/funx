defmodule Monex.TestTelemetryHelper do
  @moduledoc false

  alias Monex.TelemetryUtils

  def handle_telemetry_event(_event_name, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry_event, measurements, metadata})
  end

  def capture_telemetry(event_name, test_pid) do
    handler_id = "#{Enum.join(event_name, "-")}-test-handler"

    :telemetry.attach(
      handler_id,
      event_name,
      &Monex.TestTelemetryHelper.handle_telemetry_event/4,
      test_pid
    )

    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def telemetry_event(initial_value, transformed_value) do
    receive do
      {:telemetry_event, %{duration: duration},
       %{initial_value: received_initial, transformed_value: received_transformed}} ->
        (initial_value == received_initial or
           TelemetryUtils.summarize(initial_value) == received_initial) and
          (transformed_value == received_transformed or
             TelemetryUtils.summarize(transformed_value) == received_transformed) and
          is_integer(duration) and duration > 0
    after
      1000 -> false
    end
  end
end
