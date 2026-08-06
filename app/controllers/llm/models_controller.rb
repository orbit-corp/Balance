class Llm::ModelsController < ApplicationController
  def index
    @llm_models = available_chat_models
  end

  def show
    @llm_model = Llm::Model.find(params[:id])
  end

  def refresh
    Llm::Model.refresh!
    redirect_to models_path, notice: "Llm::Models refreshed successfully"
  end
end
