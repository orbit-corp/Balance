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
      ConfirmProposal.new(chat),
      ProposeReversal.new(chat)
    ]
  end

  temperature 0.2

  thinking effort: :medium

  params do
    { max_tokens: 2_000, seed: 42 }
  end
end
