ExUnit.start()

Path.wildcard("test/support/**/*.exs")
|> Enum.each(&Code.require_file/1)
