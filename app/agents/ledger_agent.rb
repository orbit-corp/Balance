class LedgerAgent < RubyLLM::Agent
  chat_model "Llm::Chat"

  instructions

  tools do
    [
      ListAccounts.new(chat.workspace),
      ProposeAccount.new(chat),
      ProposeEntry.new(chat),
      GetBalanceSummary.new(chat.workspace),
      ListJournalEntries.new(chat.workspace),
      CheckProposalStatus.new(chat.workspace),
      ProposeReversal.new(chat)
    ]
  end

  temperature 0.1

  thinking effort: :low

  thinking effort: :none

  params do
    { max_tokens: 2_000 }
  end
end
