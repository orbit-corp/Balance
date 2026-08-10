require "net/http"
require "uri"
require "json"

module Whatsapp
  class Client
    GRAPH_API_VERSION = "v25.0"

    def self.send_text(to:, body:)
      access_token = ENV["WHATSAPP_ACCESS_TOKEN"]
      phone_number_id = ENV["WHATSAPP_PHONE_NUMBER_ID"]

      if access_token.blank? || phone_number_id.blank?
        Rails.logger.warn("Whatsapp::Client.send_text skipped: missing WHATSAPP_ACCESS_TOKEN or WHATSAPP_PHONE_NUMBER_ID")
        return
      end

      uri = URI("https://graph.facebook.com/#{GRAPH_API_VERSION}/#{phone_number_id}/messages")

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = {
        messaging_product: "whatsapp",
        to: to,
        type: "text",
        text: { body: body }
      }.to_json

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    end

    def self.verify_signature(raw_body, signature_header)
      app_secret = ENV["WHATSAPP_APP_SECRET"]

      if app_secret.blank?
        Rails.logger.warn("Whatsapp::Client.verify_signature skipped: missing WHATSAPP_APP_SECRET")
        return true
      end

      return false if signature_header.blank?

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", app_secret, raw_body.to_s)
      ActiveSupport::SecurityUtils.secure_compare(signature_header, expected)
    end
  end
end
