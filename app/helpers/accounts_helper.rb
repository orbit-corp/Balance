module AccountsHelper
  def catalog_grouped_options_for_select(catalog)
    grouped_options_for_select(
      catalog.categories.map { |group| [ group[:category], group[:account_types].map { |entry| entry[:account_type] } ] }
    )
  end
end
