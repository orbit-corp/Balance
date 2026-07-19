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
        process_payload(JSON.parse(raw))
      rescue StandardError => e
        Rails.logger.error("Webhooks::WhatsappController#create failed: #{e.class}: #{e.message}")
      end

      head :ok
    end

    private
      def process_payload(payload)
        Array(payload["entry"]).each do |entry|
          Array(entry["changes"]).each do |change|
            value = change["value"] || {}
            process_value(value)
          end
        end
      end

      def process_value(value)
        phone_number_id = value.dig("metadata", "phone_number_id")
        profile_name = value.dig("contacts", 0, "profile", "name")

        Array(value["messages"]).each do |message|
          process_message(message, phone_number_id: phone_number_id, profile_name: profile_name)
        end
      end

      def process_message(message, phone_number_id:, profile_name:)
        wamid = message["id"]
        return if wamid.blank?
        return if WhatsappProcessedMessage.seen?(wamid)

        WhatsappProcessedMessage.record!(wamid)

        return unless message["type"] == "text"

        body = message["text"]["body"].to_s.strip
        from = message["from"]

        if body.match?(/\ALINK-[0-9A-Z]+\z/i)
          handle_linking_code(body, from, phone_number_id: phone_number_id, profile_name: profile_name)
        else
          handle_plain_text(from)
        end
      end

      def handle_linking_code(body, from, phone_number_id:, profile_name:)
        token = LinkingToken.active.find_by("upper(token) = ?", body.upcase)

        if token.nil?
          WhatsappReplyJob.perform_later(from, "That code has expired. Open Stubby and generate a new one.")
          return
        end

        workspace = token.workspace

        if WhatsappLink.active.exists?([ "wa_id = ? AND workspace_id <> ?", from, workspace.id ])
          WhatsappReplyJob.perform_later(from, "This number is already connected to another Stubby account.")
          return
        end

        token.consume!
        workspace.whatsapp_links.where(wa_id: from).destroy_all

        link = WhatsappLink.create!(
          workspace: workspace,
          wa_id: from,
          phone_number_id: phone_number_id,
          profile_name: profile_name,
          status: :active,
          requested_at: Time.current,
          linked_at: Time.current
        )

        Turbo::StreamsChannel.broadcast_replace_to(
          "workspace_#{workspace.id}_integrations",
          target: "whatsapp_integration_card",
          partial: "integrations/whatsapp_card",
          locals: { link: link, token: nil }
        )

        WhatsappReplyJob.perform_later(from, "You're connected. Forward a receipt anytime.")
      end

      def handle_plain_text(from)
        return if WhatsappLink.active.exists?(wa_id: from)

        WhatsappReplyJob.perform_later(from, "To connect, tap Connect WhatsApp in your Stubby app.")
      end
  end
end
