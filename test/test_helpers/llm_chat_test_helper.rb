module LlmChatTestHelper
  FakeMessage = Struct.new(:role, :content)

  class FakeLlmMessages
    def initialize(messages)
      @messages = messages
    end

    def where(role: nil)
      filtered = role ? @messages.select { |message| message.role == role } : @messages
      FakeLlmMessages.new(filtered)
    end

    def not(content:)
      excluded = Array(content)
      FakeLlmMessages.new(@messages.reject { |message| excluded.include?(message.content) })
    end

    def order(*)
      self
    end

    def pluck(column)
      @messages.map { |message| message.public_send(column) }
    end

    def last
      @messages.last
    end

    def to_a
      @messages
    end
  end

  def stub_llm_chat(workspace:, prompt:)
    stub_llm_chat_with_messages(workspace:, messages: [ FakeMessage.new("user", prompt) ])
  end

  def stub_llm_chat_with_messages(workspace:, messages:)
    Struct.new(:workspace, :llm_messages).new(workspace, FakeLlmMessages.new(messages))
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include LlmChatTestHelper
end
