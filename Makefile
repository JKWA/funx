
# Clean, compile, and start iex with mix
start: 
	mix clean
	mix compile
	iex -S mix

lint:
	@echo "Linting code..."
	@echo "Running Dializer..."
	MIX_ENV=dev mix dialyzer
	@echo "Running Credo..."
	MIX_ENV=dev mix credo --strict

pre_push:
	@echo "Running Credo..."
	MIX_ENV=dev mix credo --strict
	@echo "Running tests..."
	MIX_ENV=test mix test