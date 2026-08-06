class Llm::ChatsController < ApplicationController
  before_action :set_llm_chat, only: [ :show, :destroy ]

  def index
    @llm_chats = current_workspace.llm_chats.order(created_at: :desc)
  end

  def new
    @llm_chat = current_workspace.llm_chats.new
    @selected_model = params[:model]
    @chat_models = available_chat_models
  end

  def create
    prompt = params.dig(:llm_chat, :prompt)
    if prompt.present?
      @llm_chat = current_workspace.llm_chats.create!(model: params.dig(:llm_chat, :model).presence)
      LlmChatResponseJob.perform_later(@llm_chat.id, prompt)

      redirect_to chat_path(@llm_chat), notice: "Llm::chat was successfully created."
    end
  end

  def show
    @llm_message = @llm_chat.llm_messages.build
  end

  def destroy
    @llm_chat.destroy!
    redirect_to chats_path, notice: "Llm::chat was successfully destroyed.", status: :see_other
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find(params[:id])
  end
end
