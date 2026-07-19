module ApplicationHelper
  TRANSACTION_CATEGORIES = {
    "income" => %w[Sales Other],
    "expense" => [ "Restock", "Transport", "Data/Airtime", "Rent", "Utilities", "Fees", "Other" ]
  }.freeze

  def format_naira(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: "₦", precision: 2)
  end

  def transaction_party_text(transaction)
    return "—" unless transaction.income?

    transaction.customer ? "from #{transaction.customer.name}" : "—"
  end
end
