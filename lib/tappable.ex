defprotocol Funx.Tappable do
  @fallback_to_any true

  def tap(data, fun)
end

defimpl Funx.Tappable, for: Any do
  def tap(value, fun), do: Kernel.tap(value, fun)
end
