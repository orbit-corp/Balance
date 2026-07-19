class IntegrationsController < ApplicationController
  def index
    @whatsapp_link = current_workspace.whatsapp_link
    @whatsapp_token = current_workspace.linking_tokens.active.order(created_at: :desc).first
  end
end
