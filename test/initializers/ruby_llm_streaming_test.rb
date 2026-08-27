require "test_helper"
require "ruby_llm/providers/openai"

class RubyLlmStreamingTest < ActiveSupport::TestCase
  StreamEnv = Struct.new(:status) do
    def merge(body:, status:)
      Struct.new(:body, :status).new(body, status)
    end
  end

  def provider
    @provider ||= RubyLLM::Providers::OpenAI.new(RubyLLM.config)
  end

  test "raises a provider error when an error chunk has no data line" do
    error = assert_raises(RubyLLM::Error) do
      provider.send(:handle_error_chunk, "event: error\n", nil)
    end

    assert_includes error.message, "Provider stream error"
  end

  test "raises a provider error when the data line is empty" do
    assert_raises(RubyLLM::Error) do
      provider.send(:handle_error_chunk, "event: error\ndata: \n\n", nil)
    end
  end

  test "still parses a well-formed error chunk" do
    probe = provider.dup
    def probe.parse_error(response) = "boom"

    error = assert_raises(RubyLLM::Error) do
      probe.send(:handle_error_chunk, "event: error\ndata: {\"error\":{\"message\":\"boom\"}}\n\n", StreamEnv.new(500))
    end

    refute_includes error.message, "Provider stream error"
    assert_includes error.message, "boom"
  end
end
