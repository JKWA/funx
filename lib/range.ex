defimpl Funx.Foldable, for: Range do
  @spec fold_l(Range.t(), acc, (elem, acc -> acc)) :: acc when acc: term(), elem: term()
  def fold_l(range, acc, func), do: Enum.reduce(range, acc, func)

  @spec fold_r(Range.t(), acc, (elem, acc -> acc)) :: acc when acc: term(), elem: term()
  def fold_r(range, acc, func), do: Enum.reduce(Enum.reverse(range), acc, func)
end
