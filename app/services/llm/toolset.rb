class Llm::Toolset
  def self.for(chat, names)
    names.map do |name|
      case name
      when "list_accounts" then ListAccounts.new(chat.workspace)
      when "propose_account" then ProposeAccount.new(chat)
      when "propose_entry" then ProposeEntry.new(chat)
      when "get_balance_summary" then GetBalanceSummary.new(chat.workspace)
      when "list_journal_entries" then ListJournalEntries.new(chat.workspace)
      when "check_proposal_status" then CheckProposalStatus.new(chat.workspace)
      when "propose_reversal" then ProposeReversal.new(chat)
      else raise ArgumentError, "Unknown ledger tool: #{name}"
      end
    end
  end
end
