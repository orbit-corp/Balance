class FinalResponseAgent < RubyLLM::Agent
  inputs :workspace_type, :currency_code, :today
  instructions

  schema do
    string :answer
  end

  temperature 0.0
  thinking effort: :none

  params do
    { max_tokens: 240 }
  end
end
