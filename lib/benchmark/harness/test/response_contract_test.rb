require_relative "../../../../test/test_helper"

class Llm::Harness::ResponseContractTest < ActiveSupport::TestCase
  CONTRACT = {
    "required_patterns" => [ "how.*paid|cash|bank" ],
    "forbidden_patterns" => [ "personal|business|inventory" ],
    "question_count" => 1,
    "question_only" => true
  }.freeze

  test "accepts one relevant clarification question" do
    result = Llm::Harness::ResponseContract.new(
      response: "How did you pay the ₦10,000—cash, bank transfer, or another way?",
      contract: CONTRACT
    )

    assert result.valid?, result.errors.join(", ")
  end

  test "rejects redundant workspace questions" do
    result = Llm::Harness::ResponseContract.new(
      response: "Was this personal or business? How did you pay?",
      contract: CONTRACT
    )

    assert_not result.valid?
    assert result.errors.any? { |error| error.include?("must not match") }
    assert result.errors.any? { |error| error.include?("exactly 1") }
  end

  test "rejects a preamble and numbered questions" do
    result = Llm::Harness::ResponseContract.new(
      response: "Thanks. 1. How did you pay?",
      contract: CONTRACT
    )

    assert_not result.valid?
    assert result.errors.any? { |error| error.include?("preamble") }
    assert result.errors.any? { |error| error.include?("list") }
  end
end
