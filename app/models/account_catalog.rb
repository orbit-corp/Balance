class AccountCatalog
  MAP = {
    personal: AccountCatalogs::Personal,
    business: AccountCatalogs::Business
  }.with_indifferent_access.freeze

  def self.for(workspace_type)
    MAP.fetch(workspace_type) do
      raise ArgumentError, "Unsupported workspace catalog type: #{workspace_type}"
    end
  end
end
