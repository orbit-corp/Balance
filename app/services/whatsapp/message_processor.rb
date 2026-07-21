module Whatsapp
  class MessageProcessor
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload
    end

    def call
      Array(payload["entry"]).each do |entry|
        Array(entry["changes"]).each do |change|
          process_value(change["value"] || {})
        end
      end
    end

    private
      attr_reader :payload

      # The ref tag Shortlink#redirect_url inserts into a buyer's WhatsApp
      # message, e.g. "Hi, I want the serum (ref: OPXNGM3C)". A seller forwards
      # that message (or a receipt referencing it) to the bot; this is where the
      # ref comes back into Stubby — never by reading the buyer's chat directly.
      REF_TAG_PATTERN = /\(ref:\s*([A-Za-z0-9]+)\)/i

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

        from = message["from"]

        if message["type"] == "text"
          body = message["text"]["body"].to_s.strip

          if body.match?(/\ALINK-[0-9A-Z]+\z/i)
            handle_linking_code(body, from, phone_number_id: phone_number_id, profile_name: profile_name)
            WhatsappProcessedMessage.record!(wamid)
            return
          end
        end

        handle_incoming_message(message, from, phone_number_id: phone_number_id, profile_name: profile_name)
        WhatsappProcessedMessage.record!(wamid)
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

      def handle_incoming_message(message, from, phone_number_id:, profile_name:)
        link = WhatsappLink.active.find_by(wa_id: from)

        if link.nil?
          WhatsappReplyJob.perform_later(from, "To connect, tap Connect WhatsApp in your Stubby app.")
          return
        end

        persist_message(message, link)
      end

      def persist_message(message, link)
        message_type = message["type"]
        text_body = message.dig("text", "body") if message_type == "text"
        media_id = message.dig(message_type, "id")
        timestamp = message["timestamp"]
        sent_at = Time.at(timestamp.to_i) if timestamp.present?

        msg = WhatsappMessage.create!(
          workspace: link.workspace,
          whatsapp_link: link,
          wamid: message["id"],
          direction: :inbound,
          message_type: message_type,
          body: text_body,
          media_id: media_id,
          sent_at: sent_at,
          matched_shortlink: find_ref_matched_shortlink(text_body, link.workspace_id)
        )

        WhatsappMediaDownloadJob.perform_later(msg.id) if media_id.present?

        Turbo::StreamsChannel.broadcast_append_to(
          "workspace_#{link.workspace_id}_messages",
          target: "messages_thread",
          partial: "messages/message",
          locals: { message: msg }
        )
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def find_ref_matched_shortlink(text_body, workspace_id)
        return nil if text_body.blank?

        ref_code = text_body[REF_TAG_PATTERN, 1]
        return nil if ref_code.blank?

        Shortlink.joins(campaign_channel: :campaign)
                 .find_by(ref_code: ref_code.upcase, campaigns: { workspace_id: workspace_id })
      end
  end
end
