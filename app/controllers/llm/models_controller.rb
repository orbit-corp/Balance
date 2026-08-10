class Llm::ModelsController < ApplicationController
  def index
    @llm_models = available_chat_models

    @persisted_ids = Llm::Model.pluck(:provider, :model_id, :id)
      .to_h { |provider, model_id, id| [ [ provider.to_s, model_id.to_s ], id ] }
  end

  def show
    @llm_model = Llm::Model.find(params[:id])
  end

  def refresh
    Llm::Model.refresh!
    redirect_to models_path, notice: "Model list refreshed."
  end
end
