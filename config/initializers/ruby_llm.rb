RubyLLM.configure do |config|
  # Local model served by LM Studio, not OpenAI's API.
  config.openai_api_base = "http://127.0.0.1:1234/v1"
  config.openai_api_key = "lm-studio"
  config.default_model = "qwen3.5-35b-a3b"

  # Use the association-based acts_as API (recommended)
  config.use_new_acts_as = true

  # Custom model registry class name
  config.model_registry_class = "Llm::Model"
end

# LM Studio occasionally splits an SSE error event so the data line arrives in a
# separate chunk or is missing. Upstream assumes both lines arrive together and
# crashes (nil.delete_prefix), turning a provider hiccup into a generic app
# failure. Treat it as a provider error so ChatTurn's normal retry loop
# handles it.
module RubyLLM
  module Streaming
    def handle_error_chunk(chunk, env)
      data_line = chunk.split("\n")[1]
      error_data = data_line&.delete_prefix("data: ")
      raise RubyLLM::Error, "Provider stream error: #{chunk.inspect}" if error_data.blank?

      parse_error_from_json(error_data, env, "Failed to parse error chunk")
    end
  end
end
