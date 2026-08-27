class Llm::TurnsController < ApplicationController
  before_action :set_llm_chat

  def show
    turn = @llm_chat.llm_turns.find(params[:id])
    render json: {
      status: turn.status,
      terminal: turn.status.in?(%w[completed failed])
    }
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find_by!(uuid: params[:chat_uuid])
  end
end
