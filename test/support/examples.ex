defmodule Funx.Monad.Either.Dsl.Examples do
  @moduledoc """
  Example modules demonstrating the DSL pattern.

  These modules implement `run/3` from the `Funx.Monad.Dsl.Behaviour`.
  The DSL keywords (`bind`, `map`, `run`) determine how the result is handled.
  """

  defmodule ParseInt do
    @moduledoc """
    Parses a string into an integer, returning Either.

    Implements `run/3` which can be used with `bind` or `map`.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, _opts) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> right(int)
        {_int, _rest} -> left("Invalid integer: contains non-numeric characters")
        :error -> left("Invalid integer: #{value}")
      end
    end

    def run(value, _env, _opts), do: left("Expected string, got: #{inspect(value)}")
  end

  defmodule PositiveNumber do
    @moduledoc """
    Validates that a number is positive, returning Either.

    Implements `run/3` which can be used with `bind` or `map`.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, _opts) when is_number(value) and value > 0 do
      right(value)
    end

    def run(value, _env, _opts) when is_number(value) do
      left("must be positive, got: #{value}")
    end

    def run(value, _env, _opts) do
      left("expected number, got: #{inspect(value)}")
    end
  end

  defmodule Double do
    @moduledoc """
    Doubles a number, returning a plain value.

    Implements `run/3` to be used with `map`.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(value, _env \\ [], _opts \\ []) when is_number(value) do
      value * 2
    end
  end

  defmodule Square do
    @moduledoc """
    Squares a number, returning a plain value.

    Implements `run/3` to be used with `map`.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(value, _env \\ [], _opts \\ []) when is_number(value) do
      value * value
    end
  end

  defmodule FileReader do
    @moduledoc """
    Reads a file and returns tuple result.

    Demonstrates tuple support - `run/3` returns `{:ok, content}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(path, env \\ [], opts \\ [])

    def run(path, _env, _opts) when is_binary(path) do
      File.read(path)
    end

    def run(path, _env, _opts) do
      {:error, "expected string path, got: #{inspect(path)}"}
    end
  end

  defmodule JsonParser do
    @moduledoc """
    Parses JSON string, returning tuple result.

    Demonstrates tuple support - `run/3` returns `{:ok, decoded}` or
    `{:error, error}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(json_string, _env, _opts) when is_binary(json_string) do
      Jason.decode(json_string)
    end

    def run(value, _env, _opts) do
      {:error, "expected JSON string, got: #{inspect(value)}"}
    end
  end

  defmodule TupleParseInt do
    @moduledoc """
    Parses a string into an integer, returning tuple result.

    Demonstrates tuple support - `run/3` returns `{:ok, int}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(value, _env \\ [], _opts \\ []) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "Invalid integer"}
      end
    end
  end

  defmodule TupleValidator do
    @moduledoc """
    Validates that a number is positive, returning tuple result.

    Demonstrates tuple support for validation - `run/3` returns `{:ok, value}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(n, env \\ [], opts \\ [])
    def run(n, _env, _opts) when is_number(n) and n > 0, do: {:ok, n}
    def run(n, _env, _opts) when is_number(n), do: {:error, "must be positive, got: #{n}"}
    def run(value, _env, _opts), do: {:error, "expected number, got: #{inspect(value)}"}
  end

  defmodule RangeValidator do
    @moduledoc """
    Validates that a value is within a range, returning Either.

    Demonstrates validation returning Either directly.
    Accepts optional min/max via opts, defaults to 0 and 100.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, opts) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)

      if value > min and value < max do
        right(value)
      else
        left("must be between #{min} and #{max}, got: #{value}")
      end
    end

    def run(value, _env, _opts) do
      left("expected number, got: #{inspect(value)}")
    end
  end

  defmodule InvalidReturn do
    @moduledoc """
    Example of an invalid implementation that returns a plain string.

    This module demonstrates what happens when `run/3` returns an invalid type.
    Used for testing error handling in the DSL.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(_, _env \\ [], _opts \\ []), do: "not a valid return"
  end

  defmodule ParseIntWithBase do
    @moduledoc """
    Parses a string into an integer with configurable base.

    Demonstrates module-specific options - base can be passed via opts.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, opts) when is_binary(value) do
      base = Keyword.get(opts, :base, 10)

      case Integer.parse(value, base) do
        {int, ""} -> right(int)
        _ -> left("Invalid integer for base #{base}")
      end
    end

    def run(value, _env, _opts), do: left("Expected string, got: #{inspect(value)}")
  end

  defmodule MinValidator do
    @moduledoc """
    Validates that a number is above a minimum value.

    Demonstrates module-specific options - min threshold passed via opts.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, opts) when is_number(value) do
      min = Keyword.get(opts, :min, 0)

      if value > min do
        right(value)
      else
        left("must be > #{min}, got: #{value}")
      end
    end

    def run(value, _env, _opts), do: left("Expected number, got: #{inspect(value)}")
  end

  defmodule Multiplier do
    @moduledoc """
    Multiplies a number by a configurable factor.

    Demonstrates module-specific options with map - factor passed via opts.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, opts) when is_number(value) do
      factor = Keyword.get(opts, :factor, 1)
      value * factor
    end

    def run(value, _env, _opts), do: value
  end

  defmodule RangeValidatorWithOpts do
    @moduledoc """
    Validates that a value is within a configurable range.

    Demonstrates module-specific options - min and max passed via opts.
    """
    @behaviour Funx.Monad.Dsl.Behaviour

    import Funx.Monad.Either

    @impl true
    def run(value, env \\ [], opts \\ [])

    def run(value, _env, opts) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)

      if value > min and value < max do
        right(value)
      else
        left("must be between #{min} and #{max}, got: #{value}")
      end
    end

    def run(value, _env, _opts), do: left("Expected number, got: #{inspect(value)}")
  end
end
