module ApplicationHelper
  def format_naira(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: "₦", precision: 2)
  end
end
