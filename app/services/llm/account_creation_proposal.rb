class Llm::AccountCreationProposal
  attr_reader :data, :errors

  def self.from_tool(workspace:, reason:, accounts:)
    new(
      workspace: workspace,
      data: {
        "reason" => reason.to_s.strip,
        "accounts" => Array(accounts).map { |account| account.to_h.transform_keys(&:to_s).slice("name", "base_type", "account_type", "detail_type") }
      }
    )
  end

  def initialize(workspace:, data:)
    @workspace = workspace
    @data = data
    @errors = validate
  end

  def valid? = errors.empty?
  def invalid? = !valid?

  def create_accounts!
    raise ActiveRecord::RecordInvalid, candidates.find(&:invalid?) if invalid?

    Account.transaction do
      candidates.map do |candidate|
        @workspace.accounts.find_by("LOWER(name) = LOWER(?)", candidate.name) || candidate.tap(&:save!)
      end
    end
  end

  private

  def validate
    messages = []
    messages << "Explain why the account is required" if data["reason"].blank?
    messages << "Propose at least one account" if data["accounts"].blank?
    names = data["accounts"].filter_map { |account| account["name"].presence&.downcase }
    messages << "Each proposed account must have a unique name" if names.uniq.size != names.size
    existing_names = @workspace.accounts.where("LOWER(name) IN (?)", names).pluck(:name)
    messages << "These accounts already exist: #{existing_names.join(", ")}" if existing_names.any?
    candidates.each(&:valid?)
    messages.concat(candidates.flat_map { |account| account.errors.full_messages })
    messages.uniq
  end

  def candidates
    @candidates ||= data["accounts"].map do |attributes|
      existing = @workspace.accounts.find_by("LOWER(name) = LOWER(?)", attributes["name"].to_s)
      next existing if existing

      @workspace.accounts.build(attributes.slice("name", "base_type", "account_type", "detail_type"))
    end
  end
end
