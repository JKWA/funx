defmodule Funx.Config do
  @moduledoc false

  def timeout, do: Application.get_env(:funx, :timeout, 5_000)
  def telemetry_prefix, do: Application.get_env(:funx, :telemetry_prefix, [:funx])
  def telemetry_enabled?, do: Application.get_env(:funx, :telemetry_enabled, true)
  def summarizer, do: Application.get_env(:funx, :summarizer, &Funx.Summarizable.summarize/1)

  def default_span_name, do: Application.get_env(:funx, :default_span_name, "funx.effect.run")
end
