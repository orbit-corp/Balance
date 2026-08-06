class Llm::MessagesController < ApplicationController
  before_action :set_llm_chat

  def create
    content = params.dig(:llm_message, :content)
    if content.present?
      LlmChatResponseJob.perform_later(@llm_chat.id, content)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path(@llm_chat) }
      end
    end
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find(params[:chat_id])
  end
end
