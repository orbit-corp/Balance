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
