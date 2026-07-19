module Integrations
  class WhatsappController < ApplicationController
    def connect
      token = LinkingToken.issue_for(current_workspace)
      deep_link = "https://wa.me/#{ENV['WHATSAPP_BUSINESS_NUMBER']}?text=#{token.token}"

      respond_to do |format|
        format.json { render json: { deep_link: deep_link } }
        format.html { redirect_to integrations_path }
      end
    end

    def disconnect
      current_workspace.whatsapp_links.active.destroy_all
      redirect_to integrations_path
    end
  end
end
