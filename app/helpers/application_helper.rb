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

  # A sensible default description when recording a detected WhatsApp transfer.
  def review_description(extraction)
    return extraction.narration if extraction.narration.present?

    parts = []
    parts << "Transfer to #{extraction.recipient_name}" if extraction.recipient_name.present?
    parts << "Ref #{extraction.reference_number}" if extraction.reference_number.present?
    parts.join(" · ").presence
  end
end
