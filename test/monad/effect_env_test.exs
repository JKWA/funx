defmodule Funx.Monad.Effect.ContextTest do
  use ExUnit.Case, async: true
  doctest Funx.Monad.Effect.Context

  alias Funx.Monad.Effect

  describe "new/1" do
    test "generates a trace_id when none is provided" do
      context = Effect.Context.new()
      assert is_binary(context.trace_id)
      assert byte_size(context.trace_id) == 32
      assert context.baggage == %{}
      assert context.metadata == %{}
    end

    test "accepts provided values for all supported fields" do
      context =
        Effect.Context.new(
          trace_id: "abc123",
          span_name: "my span",
          timeout: 500,
          baggage: %{foo: 1},
          metadata: %{debug: true}
        )

      assert context.trace_id == "abc123"
      assert context.span_name == "my span"
      assert context.timeout == 500
      assert context.baggage == %{foo: 1}
      assert context.metadata == %{debug: true}
    end
  end

  describe "merge/2" do
    test "prefers fields from the first context and merges maps" do
      context1 =
        Effect.Context.new(
          trace_id: "1",
          span_name: "first",
          timeout: 100,
          baggage: %{a: 1},
          metadata: %{x: 1}
        )

      context2 =
        Effect.Context.new(
          trace_id: "2",
          span_name: "second",
          timeout: 200,
          baggage: %{b: 2, a: 0},
          metadata: %{y: 2, x: 0}
        )

      merged = Effect.Context.merge(context1, context2)

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
        Effect.Context.new(
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

      updated = Effect.Context.override(original, overrides)

      assert updated.trace_id == "new-id"
      assert updated.span_name == "new-span"
      assert updated.timeout == 500
      assert updated.parent_trace_id == "parent"

      assert updated.baggage == %{a: 1, b: 2, shared: "override"}
      assert updated.metadata == %{x: true, y: false, shared: "override"}
    end
  end

  describe "promote_trace/2" do
    test "creates a new trace with updated span and preserved context data" do
      context =
        Effect.Context.new(
          trace_id: "abc123",
          span_name: "start",
          timeout: 500,
          baggage: %{a: 1},
          metadata: %{m: 2}
        )

      promoted = Effect.Context.promote_trace(context, "step")

      assert promoted.trace_id != "abc123"
      assert promoted.parent_trace_id == "abc123"
      assert promoted.span_name == "step -> start"
      assert promoted.timeout == 500
      assert promoted.baggage == %{a: 1}
      assert promoted.metadata == %{m: 2}
    end

    test "uses default span name if original is nil" do
      context = Effect.Context.new(trace_id: "abc123", span_name: nil)
      promoted = Effect.Context.promote_trace(context, "task")

      assert promoted.span_name == "task -> funx.effect.run"
    end
  end

  describe "generate_trace_id/0" do
    test "produces a 32-character lowercase hex string" do
      trace_id = Effect.Context.generate_trace_id()
      assert is_binary(trace_id)
      assert trace_id =~ ~r/^[a-f0-9]{32}$/
    end
  end

  describe "span_name?/1" do
    test "returns true when span_name is present" do
      context = %Effect.Context{trace_id: "abc", span_name: "some-span"}
      assert Effect.Context.span_name?(context)
    end

    test "returns false when span_name is nil" do
      context = %Effect.Context{trace_id: "abc", span_name: nil}
      refute Effect.Context.span_name?(context)
    end
  end

  describe "default_span_name?/1" do
    test "returns true when span_name is the configured default" do
      default = Funx.Config.default_span_name()
      context = %Effect.Context{trace_id: "abc", span_name: default}
      assert Effect.Context.default_span_name?(context)
    end

    test "returns false when span_name is custom" do
      context = %Effect.Context{trace_id: "abc", span_name: "custom"}
      refute Effect.Context.default_span_name?(context)
    end
  end

  describe "empty_or_default_span_name?/1" do
    test "returns true when span_name is nil" do
      context = %Effect.Context{trace_id: "abc", span_name: nil}
      assert Effect.Context.empty_or_default_span_name?(context)
    end

    test "returns true when span_name is default" do
      context = %Effect.Context{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      assert Effect.Context.empty_or_default_span_name?(context)
    end

    test "returns false when span_name is custom" do
      context = %Effect.Context{trace_id: "abc", span_name: "custom"}
      refute Effect.Context.empty_or_default_span_name?(context)
    end
  end

  describe "default_span_name_if_empty/2" do
    test "replaces nil span_name with provided default" do
      context = %Effect.Context{trace_id: "abc", span_name: nil}
      updated = Effect.Context.default_span_name_if_empty(context, "fallback")
      assert updated.span_name == "fallback"
    end

    test "replaces default span_name with provided value" do
      context = %Effect.Context{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      updated = Effect.Context.default_span_name_if_empty(context, "fallback")
      assert updated.span_name == "fallback"
    end

    test "preserves custom span_name" do
      context = %Effect.Context{trace_id: "abc", span_name: "preserve"}
      updated = Effect.Context.default_span_name_if_empty(context, "fallback")
      assert updated.span_name == "preserve"
    end
  end
end
