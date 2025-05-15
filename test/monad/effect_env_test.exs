defmodule Funx.Effect.EnvTest do
  use ExUnit.Case, async: true
  doctest Funx.Effect.Env

  alias Funx.Effect

  describe "new/1" do
    test "generates a trace_id when none is provided" do
      env = Effect.Env.new()
      assert is_binary(env.trace_id)
      assert byte_size(env.trace_id) == 32
      assert env.baggage == %{}
      assert env.metadata == %{}
    end

    test "accepts provided values for all supported fields" do
      env =
        Effect.Env.new(
          trace_id: "abc123",
          span_name: "my span",
          timeout: 500,
          baggage: %{foo: 1},
          metadata: %{debug: true}
        )

      assert env.trace_id == "abc123"
      assert env.span_name == "my span"
      assert env.timeout == 500
      assert env.baggage == %{foo: 1}
      assert env.metadata == %{debug: true}
    end
  end

  describe "merge/2" do
    test "prefers fields from the first environment and merges maps" do
      env1 =
        Effect.Env.new(
          trace_id: "1",
          span_name: "first",
          timeout: 100,
          baggage: %{a: 1},
          metadata: %{x: 1}
        )

      env2 =
        Effect.Env.new(
          trace_id: "2",
          span_name: "second",
          timeout: 200,
          baggage: %{b: 2, a: 0},
          metadata: %{y: 2, x: 0}
        )

      merged = Effect.Env.merge(env1, env2)

      assert merged.trace_id == "1"
      assert merged.span_name == "first"
      assert merged.timeout == 100
      assert merged.baggage == %{a: 1, b: 2}
      assert merged.metadata == %{x: 1, y: 2}
    end
  end

  describe "override/2" do
    test "overrides fields with keyword values and merges maps" do
      original =
        Effect.Env.new(
          trace_id: "original",
          parent_trace_id: "parent",
          span_name: "original-span",
          timeout: 100,
          baggage: %{a: 1, shared: "keep"},
          metadata: %{x: true, shared: "keep"}
        )

      overrides = [
        trace_id: "new-id",
        span_name: "new-span",
        timeout: 500,
        baggage: %{b: 2, shared: "override"},
        metadata: %{y: false, shared: "override"}
      ]

      updated = Effect.Env.override(original, overrides)

      assert updated.trace_id == "new-id"
      assert updated.span_name == "new-span"
      assert updated.timeout == 500
      assert updated.parent_trace_id == "parent"

      assert updated.baggage == %{a: 1, b: 2, shared: "override"}
      assert updated.metadata == %{x: true, y: false, shared: "override"}
    end
  end

  describe "promote_trace/2" do
    test "creates a new trace with updated span and preserved env data" do
      env =
        Effect.Env.new(
          trace_id: "abc123",
          span_name: "start",
          timeout: 500,
          baggage: %{a: 1},
          metadata: %{m: 2}
        )

      promoted = Effect.Env.promote_trace(env, "step")

      assert promoted.trace_id != "abc123"
      assert promoted.parent_trace_id == "abc123"
      assert promoted.span_name == "step -> start"
      assert promoted.timeout == 500
      assert promoted.baggage == %{a: 1}
      assert promoted.metadata == %{m: 2}
    end

    test "uses default span name if original is nil" do
      env = Effect.Env.new(trace_id: "abc123", span_name: nil)
      promoted = Effect.Env.promote_trace(env, "task")

      assert promoted.span_name == "task -> funx.effect.run"
    end
  end

  describe "generate_trace_id/0" do
    test "produces a 32-character lowercase hex string" do
      trace_id = Effect.Env.generate_trace_id()
      assert is_binary(trace_id)
      assert trace_id =~ ~r/^[a-f0-9]{32}$/
    end
  end

  describe "span_name?/1" do
    test "returns true when span_name is present" do
      env = %Effect.Env{trace_id: "abc", span_name: "some-span"}
      assert Effect.Env.span_name?(env)
    end

    test "returns false when span_name is nil" do
      env = %Effect.Env{trace_id: "abc", span_name: nil}
      refute Effect.Env.span_name?(env)
    end
  end

  describe "default_span_name?/1" do
    test "returns true when span_name is the configured default" do
      default = Funx.Config.default_span_name()
      env = %Effect.Env{trace_id: "abc", span_name: default}
      assert Effect.Env.default_span_name?(env)
    end

    test "returns false when span_name is custom" do
      env = %Effect.Env{trace_id: "abc", span_name: "custom"}
      refute Effect.Env.default_span_name?(env)
    end
  end

  describe "empty_or_default_span_name?/1" do
    test "returns true when span_name is nil" do
      env = %Effect.Env{trace_id: "abc", span_name: nil}
      assert Effect.Env.empty_or_default_span_name?(env)
    end

    test "returns true when span_name is default" do
      env = %Effect.Env{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      assert Effect.Env.empty_or_default_span_name?(env)
    end

    test "returns false when span_name is custom" do
      env = %Effect.Env{trace_id: "abc", span_name: "custom"}
      refute Effect.Env.empty_or_default_span_name?(env)
    end
  end

  describe "default_span_name_if_empty/2" do
    test "replaces nil span_name with provided default" do
      env = %Effect.Env{trace_id: "abc", span_name: nil}
      updated = Effect.Env.default_span_name_if_empty(env, "fallback")
      assert updated.span_name == "fallback"
    end

    test "replaces default span_name with provided value" do
      env = %Effect.Env{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      updated = Effect.Env.default_span_name_if_empty(env, "fallback")
      assert updated.span_name == "fallback"
    end

    test "preserves custom span_name" do
      env = %Effect.Env{trace_id: "abc", span_name: "preserve"}
      updated = Effect.Env.default_span_name_if_empty(env, "fallback")
      assert updated.span_name == "preserve"
    end
  end
end
