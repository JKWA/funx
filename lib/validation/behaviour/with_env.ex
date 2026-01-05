defmodule Funx.Validation.Behaviour.WithEnv do
  @moduledoc """
  Behaviour for validators that need access to environmental context.

  Use this behaviour when your validator needs to access external state like:
  - Database connections
  - Existing records (for uniqueness checks)
  - Runtime configuration
  - Session data

  For simple validators that don't need external context, use `Funx.Validation.Behaviour`.

  ## Contract

  ```elixir
  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
    Funx.Monad.Either.t(any(), Funx.Errors.ValidationError.t())
    | :ok
    | {:ok, any()}
    | {:error, Funx.Errors.ValidationError.t()}
  ```

  ## Example

  ```elixir
  defmodule UniqueEmail do
    @behaviour Funx.Validation.Behaviour.WithEnv

    @impl true
    def validate(email, _opts, env) do
      db = Map.get(env, :db)
      existing_emails = Map.get(db, :emails, [])

      if email in existing_emails do
        Either.left(ValidationError.new("email already exists"))
      else
        Either.right(email)
      end
    end
  end

  # Usage
  env = %{db: %{emails: ["alice@example.com"]}}
  UniqueEmail.validate("bob@example.com", [], env)
  ```
  """

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
              Either.t(any(), ValidationError.t())
              | :ok
              | {:ok, any()}
              | {:error, ValidationError.t()}
end
