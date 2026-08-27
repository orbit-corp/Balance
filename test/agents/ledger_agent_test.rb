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
    assert_includes prompt, "only that single question"
    assert_includes prompt, "no preamble, numbered list, second question"
    assert_includes prompt, "Treat facts the user has already resolved as settled"
    assert_includes prompt, "Ask only for the missing payment source"
  end

  test "uses direct answer mode so visible tokens start without a reasoning delay" do
    assert_equal :none, LedgerAgent.thinking[:effort]
  end
end
