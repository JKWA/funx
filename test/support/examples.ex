defmodule Funx.Monad.Either.Dsl.Examples do
  @moduledoc """
  Example modules demonstrating the behavior patterns used in Either DSL.

  Modules implement one of the following behaviors based on their purpose:
  - `Funx.Validate.Behaviour` for validators (used with `validate`)
  - `Funx.Monad.Behaviour.Bind` for operations that can fail (used with `bind` and `tap`)
  - `Funx.Monad.Behaviour.Map` for pure transformations (used with `map` and `map_left`)
  - `Funx.Monad.Behaviour.Predicate` for boolean tests (used with `filter_or_else`)
  """

  defmodule ParseInt do
    @moduledoc """
    Parses a string into an integer, returning Either.

    Implements `bind/2` from Funx.Monad.Behaviour.Bind.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Either

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> right(int)
        {_int, _rest} -> left("Invalid integer: contains non-numeric characters")
        :error -> left("Invalid integer: #{value}")
      end
    end

    def bind(value, _opts, _env), do: left("Expected string, got: #{inspect(value)}")
  end

  defmodule PositiveNumber do
    @moduledoc """
    Validates that a number is positive, returning Either.

    Implements `bind/2` for use in bind operations.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Either

    @impl true
    def bind(value, _opts, _env) when is_number(value) and value > 0 do
      right(value)
    end

    def bind(value, _opts, _env) when is_number(value) do
      left("must be positive, got: #{value}")
    end

    def bind(value, _opts, _env) do
      left("expected number, got: #{inspect(value)}")
    end
  end

  defmodule Double do
    @moduledoc """
    Doubles a number, returning a plain value.

    Implements `map/2` from Funx.Monad.Behaviour.Map.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_number(value) do
      value * 2
    end
  end

  defmodule Square do
    @moduledoc """
    Squares a number, returning a plain value.

    Implements `map/2` from Funx.Monad.Behaviour.Map.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_number(value) do
      value * value
    end
  end

  defmodule FileReader do
    @moduledoc """
    Reads a file and returns tuple result.

    Demonstrates tuple support - `bind/2` returns `{:ok, content}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(path, _opts, _env) when is_binary(path) do
      File.read(path)
    end

    def bind(path, _opts, _env) do
      {:error, "expected string path, got: #{inspect(path)}"}
    end
  end

  defmodule JsonParser do
    @moduledoc """
    Parses JSON string, returning tuple result.

    Demonstrates tuple support - `bind/2` returns `{:ok, decoded}` or
    `{:error, error}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(json_string, _opts, _env) when is_binary(json_string) do
      Jason.decode(json_string)
    end

    def bind(value, _opts, _env) do
      {:error, "expected JSON string, got: #{inspect(value)}"}
    end
  end

  defmodule TupleParseInt do
    @moduledoc """
    Parses a string into an integer, returning tuple result.

    Demonstrates tuple support - `bind/2` returns `{:ok, int}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "Invalid integer"}
      end
    end
  end

  defmodule TupleValidator do
    @moduledoc """
    Validates that a number is positive, returning tuple result.

    Demonstrates tuple support for validation - `bind/2` returns `{:ok, value}` or
    `{:error, reason}` which is automatically converted to Either.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(n, _opts, _env) when is_number(n) and n > 0, do: {:ok, n}
    def bind(n, _opts, _env) when is_number(n), do: {:error, "must be positive, got: #{n}"}
    def bind(value, _opts, _env), do: {:error, "expected number, got: #{inspect(value)}"}
  end

  defmodule InvalidReturn do
    @moduledoc """
    Example of an invalid implementation that returns a plain string.

    This module demonstrates what happens when `bind/2` returns an invalid type.
    Used for testing error handling in the DSL.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(_, _opts, _env), do: "not a valid return"
  end

  defmodule ParseIntWithBase do
    @moduledoc """
    Parses a string into an integer with configurable base.

    Demonstrates module-specific options - base can be passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Either

    @impl true
    def bind(value, opts, _env) when is_binary(value) do
      base = Keyword.get(opts, :base, 10)

      case Integer.parse(value, base) do
        {int, ""} -> right(int)
        _ -> left("Invalid integer for base #{base}")
      end
    end

    def bind(value, _opts, _env), do: left("Expected string, got: #{inspect(value)}")
  end

  defmodule Multiplier do
    @moduledoc """
    Multiplies a number by a configurable factor.

    Demonstrates module-specific options with map - factor passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, opts, _env) when is_number(value) do
      factor = Keyword.get(opts, :factor, 1)
      value * factor
    end

    def map(value, _opts, _env), do: value
  end

  defmodule RangeValidatorWithOpts do
    @moduledoc """
    Validates that a value is within a configurable range.

    Demonstrates module-specific options - min and max passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Either

    @impl true
    def bind(value, opts, _env) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)

      if value > min and value < max do
        right(value)
      else
        left("must be between #{min} and #{max}, got: #{value}")
      end
    end

    def bind(value, _opts, _env), do: left("Expected number, got: #{inspect(value)}")
  end

  defmodule Logger do
    @moduledoc """
    Logs a value for side effects, used with tap.

    Demonstrates tap with module - sends message to test process.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, opts, _env) do
      test_pid = Keyword.get(opts, :test_pid)
      label = Keyword.get(opts, :label, :logged)

      if test_pid do
        send(test_pid, {label, value})
      end

      value
    end
  end

  defmodule ErrorWrapper do
    @moduledoc """
    Wraps an error message with a prefix, used with map_left.

    Demonstrates map_left with module using Map behavior.
    Note: env is not used since error transformations are pure.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(error, opts, _env) do
      prefix = Keyword.get(opts, :prefix, "Error")
      "#{prefix}: #{error}"
    end
  end

  defmodule IsPositive do
    @moduledoc """
    Predicate that checks if a number is positive.

    Demonstrates filter_or_else with module predicate using Predicate behavior.
    """
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, _opts, _env) when is_number(value) do
      value > 0
    end

    def predicate(_value, _opts, _env), do: false
  end

  defmodule InRange do
    @moduledoc """
    Predicate that checks if a value is within a range.

    Demonstrates filter_or_else with module predicate and options using Predicate behavior.
    """
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, opts, _env) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)
      value >= min and value <= max
    end

    def predicate(_value, _opts, _env), do: false
  end

  defmodule Adder do
    @moduledoc """
    Produces a function that adds the input value.

    Demonstrates ap with module - implements Ap behavior.
    """
    @behaviour Funx.Monad.Behaviour.Ap

    import Funx.Monad.Either

    @impl true
    def ap(value, _opts, _env) when is_number(value) do
      right(fn x -> x + value end)
    end

    def ap(value, _opts, _env), do: left("Expected number for adder, got: #{inspect(value)}")
  end
end

defmodule Funx.Monad.Maybe.Dsl.Examples do
  @moduledoc """
  Example modules demonstrating the behavior patterns used in Maybe DSL.

  Modules implement one of the following behaviors based on their purpose:
  - `Funx.Monad.Behaviour.Bind` for operations that can fail (used with `bind`, `tap`, `filter_map`)
  - `Funx.Monad.Behaviour.Map` for pure transformations (used with `map`)
  - `Funx.Monad.Behaviour.Predicate` for boolean tests (used with `filter`, `guard`)
  - `Funx.Monad.Behaviour.Ap` for applicative functors (used with `ap`)
  """

  defmodule ParseInt do
    @moduledoc """
    Parses a string into an integer, returning Maybe.

    Implements `bind/3` from Funx.Monad.Behaviour.Bind.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Maybe

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> just(int)
        {_int, _rest} -> nothing()
        :error -> nothing()
      end
    end

    def bind(_value, _opts, _env), do: nothing()
  end

  defmodule PositiveNumber do
    @moduledoc """
    Validates that a number is positive, returning Maybe.

    Implements `bind/3` for use in bind operations.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Maybe

    @impl true
    def bind(value, _opts, _env) when is_number(value) and value > 0 do
      just(value)
    end

    def bind(_value, _opts, _env), do: nothing()
  end

  defmodule Double do
    @moduledoc """
    Doubles a number, returning a plain value.

    Implements `map/3` from Funx.Monad.Behaviour.Map.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_number(value) do
      value * 2
    end
  end

  defmodule Square do
    @moduledoc """
    Squares a number, returning a plain value.

    Implements `map/3` from Funx.Monad.Behaviour.Map.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_number(value) do
      value * value
    end
  end

  defmodule TupleParseInt do
    @moduledoc """
    Parses a string into an integer, returning tuple result.

    Demonstrates tuple support - `bind/3` returns `{:ok, int}` or
    `{:error, reason}` which is automatically converted to Maybe.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "Invalid integer"}
      end
    end
  end

  defmodule TupleValidator do
    @moduledoc """
    Validates that a number is positive, returning tuple result.

    Demonstrates tuple support for validation - `bind/3` returns `{:ok, value}` or
    `{:error, reason}` which is automatically converted to Maybe.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(n, _opts, _env) when is_number(n) and n > 0, do: {:ok, n}
    def bind(_n, _opts, _env), do: {:error, "not positive"}
  end

  defmodule InvalidReturn do
    @moduledoc """
    Example of an invalid implementation that returns a plain string.

    This module demonstrates what happens when `bind/3` returns an invalid type.
    Used for testing error handling in the DSL.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(_, _opts, _env), do: "not a valid return"
  end

  defmodule ParseIntWithBase do
    @moduledoc """
    Parses a string into an integer with configurable base.

    Demonstrates module-specific options - base can be passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Maybe

    @impl true
    def bind(value, opts, _env) when is_binary(value) do
      base = Keyword.get(opts, :base, 10)

      case Integer.parse(value, base) do
        {int, ""} -> just(int)
        _ -> nothing()
      end
    end

    def bind(_value, _opts, _env), do: nothing()
  end

  defmodule MinValidator do
    @moduledoc """
    Validates that a number is above a minimum value.

    Demonstrates module-specific options - min threshold passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    import Funx.Monad.Maybe

    @impl true
    def bind(value, opts, _env) when is_number(value) do
      min = Keyword.get(opts, :min, 0)

      if value > min do
        just(value)
      else
        nothing()
      end
    end

    def bind(_value, _opts, _env), do: nothing()
  end

  defmodule Multiplier do
    @moduledoc """
    Multiplies a number by a configurable factor.

    Demonstrates module-specific options with map - factor passed via opts.
    """
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, opts, _env) when is_number(value) do
      factor = Keyword.get(opts, :factor, 1)
      value * factor
    end

    def map(value, _opts, _env), do: value
  end

  defmodule Logger do
    @moduledoc """
    Logs a value for side effects, used with tap.

    Demonstrates tap with module - sends message to test process.
    """
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, opts, _env) do
      test_pid = Keyword.get(opts, :test_pid)
      label = Keyword.get(opts, :label, :logged)

      if test_pid do
        send(test_pid, {label, value})
      end

      value
    end
  end

  defmodule IsPositive do
    @moduledoc """
    Predicate that checks if a number is positive.

    Used with filter and guard operations.
    """
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, _opts, _env) when is_number(value) do
      value > 0
    end

    def predicate(_value, _opts, _env), do: false
  end

  defmodule InRange do
    @moduledoc """
    Predicate that checks if a value is within a range.

    Used with filter and guard operations with options.
    """
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, opts, _env) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)
      value >= min and value <= max
    end

    def predicate(_value, _opts, _env), do: false
  end
end
