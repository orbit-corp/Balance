class LedgerAgent < RubyLLM::Agent
  chat_model "Llm::Chat"

  instructions

  tools { [ ListAccounts.new(chat.workspace), ProposeEntry.new(chat.workspace) ] }

  temperature 0.2
end
