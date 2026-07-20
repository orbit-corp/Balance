module Webhooks
  class WhatsappController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def show
      if params["hub.verify_token"] == ENV["WHATSAPP_VERIFY_TOKEN"]
        render plain: params["hub.challenge"]
      else
        head :forbidden
      end
    end

    def create
      raw = request.raw_post

      unless Whatsapp::Client.verify_signature(raw, request.headers["X-Hub-Signature-256"])
        head :forbidden
        return
      end

      begin
        Whatsapp::MessageProcessor.call(JSON.parse(raw))
      rescue StandardError => e
        Rails.logger.error("Webhooks::WhatsappController#create failed: #{e.class}: #{e.message}")
      end

      head :ok
    end
  end
end
