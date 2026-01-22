defmodule Funx.Config do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fconfig%2Fconfig.livemd)

  Internal access to `:funx` application configuration.

  These functions read from `Application.get_env/3` with sane defaults.
  Used by effect modules for settings like timeouts, telemetry, and summarization.

  ## Supported config keys

  - `:timeout` — default timeout for running effects (default: `5_000` ms)
  - `:telemetry_prefix` — base prefix for telemetry events (default: `[:funx]`)
  - `:telemetry_enabled` — whether telemetry spans are emitted (default: `true`)
  - `:summarizer` — function used to summarize effect results for telemetry
  - `:default_span_name` — fallback span name for telemetry traces
  """

  def timeout, do: Application.get_env(:funx, :timeout, 5_000)
  def telemetry_prefix, do: Application.get_env(:funx, :telemetry_prefix, [:funx])
  def telemetry_enabled?, do: Application.get_env(:funx, :telemetry_enabled, true)
  def summarizer, do: Application.get_env(:funx, :summarizer, &Funx.Summarizable.summarize/1)
  def default_span_name, do: Application.get_env(:funx, :default_span_name, "funx.effect.run")
end
