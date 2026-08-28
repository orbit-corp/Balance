require "test_helper"

class Llm::TurnClassifierTest < ActiveSupport::TestCase
  Response = Data.define(:content)

  class FakeAgent
    def initialize(result)
      @result = result
    end

    def ask(*)
      Response.new(@result)
    end
  end

  setup do
    @chat = Llm::Chat.create!(
      workspace: workspaces(:ada_store),
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Classifier test"),
      title: "Classifier test"
    )
  end

  test "does not require the user to provide accounting classification or payment source" do
    turn = build_turn("i received 2k from my girlfriend")
    result = transaction_result(
      summary: "Received 2,000 from girlfriend",
      amount: "2000 NGN",
      classification: "",
      payment_source: "",
      missing_facts: %w[classification payment_source]
    )

    classify(turn, result)

    assert turn.reload.classification.dig("transaction", "ready")
    assert_empty turn.classification.dig("transaction", "missing_facts")
    assert_equal %w[list_accounts propose_account propose_entry], turn.allowed_tools
    assert_equal Date.current.iso8601, turn.classification.dig("transaction", "date")
  end

  test "derives shorthand and bare amounts from ordinary transaction descriptions" do
    shorthand = build_turn("i received 2k from my girlfriend")
    classify(shorthand, transaction_result(summary: "Received money from girlfriend", amount: "", missing_facts: [ "amount" ]))

    assert_equal "2000 NGN", shorthand.reload.classification.dig("transaction", "amount")
    assert shorthand.classification.dig("transaction", "ready")

    bare = build_turn("I paid 5000 for transport")
    classify(bare, transaction_result(summary: "Paid for transport", amount: "", missing_facts: [ "amount" ]))

    assert_equal "5000 NGN", bare.reload.classification.dig("transaction", "amount")
    assert bare.classification.dig("transaction", "ready")
  end

  test "grounds an owner contribution event and amount from ordinary language" do
    turn = build_turn("Owner puts ₦100,000 of their own money into the business bank account.")
    classify(turn, transaction_result(summary: "", amount: ",100000", missing_facts: [ "event" ]))

    facts = turn.reload.classification.fetch("transaction")
    assert_equal "Owner puts ₦100,000 of their own money into the business bank account.", facts["summary"]
    assert_equal "100000 NGN", facts["amount"]
    assert facts["ready"]
  end

  test "does not turn missing payment source into serialized message history" do
    turn = build_turn("I paid 2k for transport")
    classify(turn, transaction_result(summary: "Paid for transport", payment_source: ""))

    assert_nil turn.reload.classification.dig("transaction", "payment_source")
  end

  test "asks for the economic event and amount when the user only announces an intention" do
    turn = build_turn("I want to record a transaction")
    result = transaction_result(summary: "", amount: "", missing_facts: %w[event amount])

    classify(turn, result)

    refute turn.reload.classification.dig("transaction", "ready")
    assert_equal %w[event amount], turn.classification.dig("transaction", "missing_facts")
    assert_empty turn.allowed_tools
  end

  test "routes explicit journal proposal approval only to confirmation" do
    turn = build_turn("record it")
    result = transaction_result(intent: "proposal_confirmation", relationship: "continuation")

    classify(turn, result)

    assert_equal "proposal_confirmation", turn.reload.intent
    assert_equal [ "confirm_proposal" ], turn.allowed_tools
  end

  test "separates reversal lookup from confirmed reversal preparation" do
    request = build_turn("reverse my latest journal entry")
    classify(request, transaction_result(intent: "reversal", relationship: "new"))
    assert_equal [ "list_journal_entries" ], request.reload.allowed_tools

    confirmation = build_turn("yes")
    classify(confirmation, transaction_result(intent: "reversal_confirmation", relationship: "continuation"))
    assert_equal [ "propose_reversal" ], confirmation.reload.allowed_tools
  end

  test "keeps resolved facts across transaction follow-ups" do
    first = build_turn("i received 2k from my girlfriend")
    classify(first, transaction_result(summary: "Received money from girlfriend", amount: "2000 NGN"))

    follow_up = build_turn("it was repayment in cash")
    classify(follow_up, transaction_result(
      relationship: "continuation",
      summary: "",
      amount: "",
      classification: "loan repayment",
      payment_source: "cash",
      missing_facts: [ "amount" ]
    ))

    facts = follow_up.reload.classification.fetch("transaction")
    assert_equal "Received money from girlfriend", facts["summary"]
    assert_equal "2000 NGN", facts["amount"]
    assert_equal "loan repayment", facts["classification"]
    assert_equal "cash", facts["payment_source"]
    assert facts["ready"]
  end

  test "pauses a pending transaction for an unrelated greeting without tools" do
    first = build_turn("i received 2k from my girlfriend")
    classify(first, transaction_result(summary: "Received money from girlfriend", amount: "2000 NGN"))
    session = first.reload.llm_transaction_session

    greeting = build_turn("hi")
    classify(greeting, transaction_result(intent: "conversation", relationship: "unrelated", summary: "", amount: ""))

    assert_equal "conversation", greeting.reload.intent
    assert_empty greeting.allowed_tools
    assert_equal "paused", session.reload.status
  end

  private

  def build_turn(content)
    message = @chat.llm_messages.create!(role: "user", content: content)
    @chat.llm_turns.create!(user_message: message)
  end

  def classify(turn, result)
    described_class = Llm::TurnClassifier.new(chat: @chat, turn: turn, agent: FakeAgent.new(result))
    described_class.call
  end

  def transaction_result(intent: "transaction", relationship: "new", summary: "Transaction", amount: "2000 NGN",
    payment_source: "", classification: "", missing_facts: [])
    {
      intent: intent,
      relationship: relationship,
      progress_message: "",
      transaction: {
        summary: summary,
        amount: amount,
        payment_source: payment_source,
        date: "",
        classification: classification,
        counterparty: "",
        extra_facts: [],
        missing_facts: missing_facts,
        ready: missing_facts.empty?
      }
    }
  end
end
