class TurnClassifierAgent < RubyLLM::Agent
  INTENTS = %w[
    conversation transaction balance journal_entries account_setup proposal_status reversal refusal
  ].freeze

  inputs :workspace_type, :currency_code, :today, :pending_transaction, :recent_transaction
  instructions

  schema do
    string :intent, enum: INTENTS
    string :relationship, enum: %w[new continuation unrelated]
    string :progress_message
    object :transaction do
      string :summary
      string :amount
      string :payment_source
      string :date
      string :classification
      string :counterparty
      array :extra_facts do
        string
      end
      array :missing_facts do
        string
      end
      boolean :ready
    end
  end

  temperature 0.0
  thinking effort: :none

  params do
    { max_tokens: 900 }
  end
end
