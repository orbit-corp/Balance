class Llm::MessagesController < ApplicationController
  before_action :set_llm_chat

  def create
    content = params.dig(:llm_message, :content)
    return head :no_content if content.blank?

    @llm_message = @llm_chat.start_turn(content)
    @llm_turn = @llm_message.llm_turn

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chat_path(@llm_chat) }
    end
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find_by!(uuid: params[:chat_uuid])
  end
end
