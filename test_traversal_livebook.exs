Mix.install([{:funx, path: "."}])

alias Funx.Optics.{Lens, Prism, Traversal}
alias Funx.Monad.Maybe
use Funx.Monad.Maybe

defmodule Item, do: defstruct [:name, :amount]
defmodule CreditCard, do: defstruct [:name, :number, :amount]
defmodule Transaction, do: defstruct [:item, :payment]

item_amount_lens = Lens.path([:item, :amount])
cc_payment_prism = Prism.path([:payment, CreditCard])
cc_amount_prism = Prism.compose(cc_payment_prism, Prism.key(:amount))
cc_amounts_trav = Traversal.combine([item_amount_lens, cc_amount_prism])

cc_transaction = %Transaction{
  item: %Item{name: "Camera", amount: 500},
  payment: %CreditCard{name: "Alice", number: "4111", amount: 500}
}

defmodule ValidateAmounts do
  def run_maybe([item_amount, payment_amount], _opts, _env) do
    item_amount == payment_amount
  end
end

IO.puts("Testing: Traversal.to_list_maybe with matching amounts")
result = maybe cc_transaction do
  bind Traversal.to_list_maybe(cc_amounts_trav)
  guard ValidateAmounts
end

IO.inspect(result, label: "Result")
