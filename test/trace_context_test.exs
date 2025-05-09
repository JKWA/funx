defmodule Funx.TraceContextTest do
  use ExUnit.Case, async: true
  doctest Funx.TraceContext

  alias Funx.TraceContext

  describe "new/1" do
    test "generates a trace_id when none is provided" do
      ctx = TraceContext.new()
      assert is_binary(ctx.trace_id)
      assert byte_size(ctx.trace_id) == 32
    end

    test "accepts a provided trace_id and fields" do
      ctx = TraceContext.new(trace_id: "abc123", span_name: "my span", timeout: 500)
      assert ctx.trace_id == "abc123"
      assert ctx.span_name == "my span"
      assert ctx.timeout == 500
    end
  end

  describe "merge/2" do
    test "prefers fields from the first context when present" do
      ctx1 = TraceContext.new(trace_id: "1", span_name: "first", timeout: 100, baggage: %{a: 1})
      ctx2 = TraceContext.new(trace_id: "2", span_name: "second", timeout: 200, baggage: %{b: 2})

      merged = TraceContext.merge(ctx1, ctx2)
      assert merged.trace_id == "1"
      assert merged.span_name == "first"
      assert merged.timeout == 100
      assert merged.baggage == %{a: 1, b: 2}
    end
  end

  describe "promote/2" do
    test "creates a new trace with promoted parent_trace_id and updated span name" do
      ctx = TraceContext.new(trace_id: "abc123", span_name: "start", timeout: 500)
      promoted = TraceContext.promote(ctx, "step")

      assert promoted.trace_id != "abc123"
      assert promoted.parent_trace_id == "abc123"
      assert promoted.span_name == "step -> start"
      assert promoted.timeout == 500
    end

    test "uses default span fallback if missing" do
      ctx = TraceContext.new(trace_id: "abc123", span_name: nil)
      promoted = TraceContext.promote(ctx, "task")

      assert promoted.span_name == "task -> funx.effect.run"
    end
  end

  describe "generate_trace_id/0" do
    test "produces a 32-character lowercase hex string" do
      trace_id = TraceContext.generate_trace_id()
      assert is_binary(trace_id)
      assert trace_id =~ ~r/^[a-f0-9]{32}$/
    end
  end

  describe "span_name?/1" do
    test "returns true when span_name is present" do
      ctx = %TraceContext{trace_id: "abc", span_name: "some-span"}
      assert TraceContext.span_name?(ctx)
    end

    test "returns false when span_name is nil" do
      ctx = %TraceContext{trace_id: "abc", span_name: nil}
      refute TraceContext.span_name?(ctx)
    end
  end

  describe "default_span_name?/1" do
    test "returns true when span_name is the configured default" do
      default = Funx.Config.default_span_name()
      ctx = %TraceContext{trace_id: "abc", span_name: default}
      assert TraceContext.default_span_name?(ctx)
    end

    test "returns false when span_name is custom" do
      ctx = %TraceContext{trace_id: "abc", span_name: "custom"}
      refute TraceContext.default_span_name?(ctx)
    end
  end

  describe "empty_or_default_span_name?/1" do
    test "returns true when span_name is nil" do
      ctx = %TraceContext{trace_id: "abc", span_name: nil}
      assert TraceContext.empty_or_default_span_name?(ctx)
    end

    test "returns true when span_name is default" do
      ctx = %TraceContext{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      assert TraceContext.empty_or_default_span_name?(ctx)
    end

    test "returns false when span_name is custom" do
      ctx = %TraceContext{trace_id: "abc", span_name: "custom"}
      refute TraceContext.empty_or_default_span_name?(ctx)
    end
  end

  describe "default_span_name_if_empty/2" do
    test "replaces nil span_name with provided default" do
      ctx = %TraceContext{trace_id: "abc", span_name: nil}
      updated = TraceContext.default_span_name_if_empty(ctx, "fallback")
      assert updated.span_name == "fallback"
    end

    test "replaces default span_name with provided value" do
      ctx = %TraceContext{trace_id: "abc", span_name: Funx.Config.default_span_name()}
      updated = TraceContext.default_span_name_if_empty(ctx, "fallback")
      assert updated.span_name == "fallback"
    end

    test "preserves custom span_name" do
      ctx = %TraceContext{trace_id: "abc", span_name: "preserve"}
      updated = TraceContext.default_span_name_if_empty(ctx, "fallback")
      assert updated.span_name == "preserve"
    end
  end
end
