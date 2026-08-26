class Llm::Harness::ResponseContract
  attr_reader :errors

  def initialize(response:, contract:)
    @response = response.to_s.strip
    @contract = contract || {}
    @errors = validate
  end

  def valid? = errors.empty?

  private

  attr_reader :response, :contract

  def validate
    [].tap do |messages|
      validate_required_patterns(messages)
      validate_forbidden_patterns(messages)
      validate_question_count(messages)
      validate_question_only(messages) if contract["question_only"]
    end
  end

  def validate_required_patterns(messages)
    Array(contract["required_patterns"]).each do |pattern|
      messages << "must match /#{pattern}/" unless response.match?(regexp(pattern))
    end
  end

  def validate_forbidden_patterns(messages)
    Array(contract["forbidden_patterns"]).each do |pattern|
      messages << "must not match /#{pattern}/" if response.match?(regexp(pattern))
    end
  end

  def validate_question_count(messages)
    return unless contract.key?("question_count")

    expected = contract.fetch("question_count")
    actual = response.count("?")
    messages << "must contain exactly #{expected} question mark(s), found #{actual}" unless actual == expected
  end

  def validate_question_only(messages)
    messages << "must contain only one question" unless response.end_with?("?")
    messages << "must not contain a preamble or second sentence" if response.match?(/[.!]\s+\S/)
    list_pattern = /(?:\A|\n|[.!?]\s+)\s*(?:[-*]|\d+[.)])\s+/
    messages << "must not use a list for one clarification" if response.match?(list_pattern)
  end

  def regexp(pattern)
    Regexp.new(pattern, Regexp::IGNORECASE)
  end
end
