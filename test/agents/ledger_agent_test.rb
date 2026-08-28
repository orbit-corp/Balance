require "test_helper"

class LedgerAgentTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Prompt test"),
      title: "Prompt test"
    )
  end

  test "renders authoritative workspace context and a single-question clarification contract" do
    prompt = LedgerAgent.render_prompt("instructions", chat: @chat, inputs: {}, locals: {})

    assert_includes prompt, "Type: personal"
    assert_includes prompt, "Currency: NGN"
    assert_includes prompt, "Never ask whether a transaction is personal or business"
    assert_includes prompt, "exactly one short question"
    assert_includes prompt, "no preamble, list, second question"
    assert_includes prompt, "Treat facts the user has already resolved as settled"
    assert_includes prompt, "Never ask the user to classify a transaction"
    assert_includes prompt, "existing account; otherwise use the closest recommendation"
    assert_includes prompt, "immediately prepare the original journal-entry proposal"
  end

  test "uses medium reasoning effort for transaction interpretation" do
    assert_equal :medium, LedgerAgent.thinking[:effort]
  end
end
