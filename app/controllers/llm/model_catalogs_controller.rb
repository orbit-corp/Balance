class Llm::ModelCatalogsController < ApplicationController
  def update
    Llm::Model.refresh!
    redirect_to models_path, notice: "Model list refreshed."
  end
end
