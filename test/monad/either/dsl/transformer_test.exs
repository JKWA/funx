defmodule Funx.Monad.Either.Dsl.TransformerTest do
  @moduledoc """
  Tests for the Either DSL Transformer behaviour and built-in transformers.
  """

  use ExUnit.Case, async: true
  use Funx.Monad.Either

  alias Funx.Monad.Either.Dsl.Step
  alias Funx.Monad.Either.Dsl.Transformer

  describe "Transformer.apply_transformers/3" do
    test "returns steps unchanged when no transformers provided" do
      steps = [
        %Step.Bind{operation: String, opts: []},
        %Step.Map{operation: String, opts: []}
      ]

      assert {:ok, ^steps} = Transformer.apply_transformers(steps, [], [])
    end

    test "applies single transformer" do
      defmodule SingleTransformer do
        @behaviour Transformer
        def transform(steps, _opts) do
          {:ok, steps ++ [%Step.Map{operation: String, opts: []}]}
        end
      end

      steps = [
        %Step.Bind{operation: String, opts: []}
      ]

      assert {:ok, result} = Transformer.apply_transformers(steps, [SingleTransformer], [])
      assert length(result) == 2
    end

    test "applies multiple transformers in order" do
      steps = [%Step.Bind{operation: String, opts: []}]

      defmodule FirstTransformer do
        @behaviour Transformer
        def transform(steps, _opts) do
          {:ok, steps ++ [%Step.Map{operation: String, opts: [], __meta__: %{order: 1}}]}
        end
      end

      defmodule SecondTransformer do
        @behaviour Transformer
        def transform(steps, _opts) do
          {:ok, steps ++ [%Step.Map{operation: String, opts: [], __meta__: %{order: 2}}]}
        end
      end

      assert {:ok, result} =
               Transformer.apply_transformers(steps, [FirstTransformer, SecondTransformer], [])

      assert length(result) == 3
      assert Enum.at(result, 1).__meta__.order == 1
      assert Enum.at(result, 2).__meta__.order == 2
    end

    test "stops on first error" do
      steps = [%Step.Bind{operation: String, opts: []}]

      defmodule ErrorTransformer do
        @behaviour Transformer
        def transform(_steps, _opts), do: {:error, "transformation failed"}
      end

      defmodule NeverRunTransformer do
        @behaviour Transformer
        def transform(steps, _opts), do: {:ok, steps ++ [%Step.Map{operation: String, opts: []}]}
      end

      assert {:error, "transformation failed"} =
               Transformer.apply_transformers(steps, [ErrorTransformer, NeverRunTransformer], [])
    end

    test "passes opts to transformers" do
      steps = [%Step.Bind{operation: String, opts: []}]

      defmodule OptsTransformer do
        @behaviour Transformer
        def transform(steps, opts) do
          if Keyword.get(opts, :should_add) do
            {:ok, steps ++ [%Step.Map{operation: String, opts: []}]}
          else
            {:ok, steps}
          end
        end
      end

      assert {:ok, result1} =
               Transformer.apply_transformers(steps, [OptsTransformer], should_add: true)

      assert length(result1) == 2

      assert {:ok, result2} =
               Transformer.apply_transformers(steps, [OptsTransformer], should_add: false)

      assert length(result2) == 1
    end
  end

  describe "Integration with DSL" do
    defmodule TestTransformer do
      @behaviour Transformer

      def transform(steps, _opts) do
        # Add a map step at the end with a quoted operation
        map_step = %Step.Map{
          operation: quote(do: fn x -> {:transformed, x} end),
          opts: []
        }

        {:ok, steps ++ [map_step]}
      end
    end

    test "applies transformer during compilation" do
      result =
        either 42, transformers: [TestTransformer], as: :tuple do
          map &(&1 * 2)
        end

      # Should have applied both the explicit map and the transformer's map
      assert {:ok, {:transformed, 84}} = result
    end

    test "raises CompileError when transformers is not a list" do
      assert_raise CompileError, ~r/Invalid transformers.*Must be a list of modules/, fn ->
        Code.eval_quoted(
          quote do
            require Funx.Monad.Either.Dsl
            import Funx.Monad.Either.Dsl

            either 42, transformers: :not_a_list do
              map &(&1 * 2)
            end
          end
        )
      end
    end

    defmodule ErrorTransformerString do
      @behaviour Transformer

      def transform(_steps, _opts) do
        {:error, "custom transformation error"}
      end
    end

    test "raises CompileError when transformer returns string error" do
      assert_raise CompileError, "custom transformation error", fn ->
        Code.eval_quoted(
          quote do
            require Funx.Monad.Either.Dsl
            import Funx.Monad.Either.Dsl
            alias Funx.Monad.Either.Dsl.TransformerTest.ErrorTransformerString

            either 42, transformers: [ErrorTransformerString] do
              map &(&1 * 2)
            end
          end
        )
      end
    end

    defmodule ErrorTransformerException do
      @behaviour Transformer

      def transform(_steps, _opts) do
        {:error, %ArgumentError{message: "custom exception error"}}
      end
    end

    test "raises exception when transformer returns exception error" do
      assert_raise ArgumentError, "custom exception error", fn ->
        Code.eval_quoted(
          quote do
            require Funx.Monad.Either.Dsl
            import Funx.Monad.Either.Dsl
            alias Funx.Monad.Either.Dsl.TransformerTest.ErrorTransformerException

            either 42, transformers: [ErrorTransformerException] do
              map &(&1 * 2)
            end
          end
        )
      end
    end
  end
end
