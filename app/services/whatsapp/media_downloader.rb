# Downloads media referenced by an inbound WhatsApp message from Meta's Graph API.
# Two-step: resolve the short-lived download URL from the media id, then fetch the
# binary (following redirects to the fbsbx.com CDN). Required ENV: WHATSAPP_ACCESS_TOKEN.
require "net/http"
require "uri"
require "json"
require "stringio"

module Whatsapp
  class MediaDownloader
    class DownloadError < StandardError; end

    GRAPH_API_VERSION = "v25.0"
    REDIRECT_LIMIT = 5

    EXTENSIONS = {
      "image/jpeg" => "jpg",
      "image/png" => "png",
      "image/webp" => "webp",
      "image/gif" => "gif",
      "video/mp4" => "mp4",
      "video/3gpp" => "3gp",
      "audio/mpeg" => "mp3",
      "audio/ogg" => "ogg",
      "audio/aac" => "aac",
      "audio/amr" => "amr",
      "application/pdf" => "pdf",
      "application/msword" => "doc",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "docx",
      "application/vnd.ms-excel" => "xls",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "xlsx",
      "text/plain" => "txt"
    }.freeze
    private_constant :EXTENSIONS

    def self.call(media_id)
      new(media_id).call
    end

    def initialize(media_id)
      @media_id = media_id
    end

    def call
      if access_token.blank?
        raise DownloadError, "#{log_prefix} skipped: missing WHATSAPP_ACCESS_TOKEN"
      end

      metadata = fetch_metadata
      media_url = metadata["url"]
      mime_type = metadata["mime_type"]
      raise DownloadError, "#{log_prefix}: metadata missing url for #{media_id}" if media_url.blank?

      body = fetch_binary(media_url)

      { io: StringIO.new(body), content_type: mime_type, filename: filename_for(mime_type) }
    end

    private
      attr_reader :media_id

      def access_token
        ENV["WHATSAPP_ACCESS_TOKEN"]
      end

      def fetch_metadata
        with_download_errors do
          uri = URI("https://graph.facebook.com/#{GRAPH_API_VERSION}/#{media_id}")
          request = Net::HTTP::Get.new(uri)
          request["Authorization"] = "Bearer #{access_token}"

          response = get(uri, request)

          unless response.is_a?(Net::HTTPSuccess)
            raise DownloadError, "#{log_prefix} metadata non-success: #{response.code} #{response.message} body=#{response.body.to_s.truncate(500)}"
          end

          JSON.parse(response.body)
        end
      end

      def fetch_binary(media_url)
        with_download_errors do
          uri = URI(media_url)

          REDIRECT_LIMIT.times do
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "stubby/1.0"
            request["Authorization"] = "Bearer #{access_token}" if meta_host?(uri.host)

            response = get(uri, request)

            case response
            when Net::HTTPSuccess
              return response.body
            when Net::HTTPRedirection
              uri = URI.join(uri.to_s, response["location"])
            else
              raise DownloadError, "#{log_prefix} binary non-success: #{response.code} #{response.message}"
            end
          end

          raise DownloadError, "#{log_prefix} exceeded redirect limit"
        end
      end

      def get(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          http.request(request)
        end
      end

      # Only attach the bearer token when talking to Meta-owned hosts, so a
      # redirect to a third-party CDN can't capture the access token.
      def meta_host?(host)
        host = host.to_s
        %w[facebook.com fbsbx.com].any? { |domain| host == domain || host.end_with?(".#{domain}") }
      end

      def filename_for(mime_type)
        "#{media_id}.#{EXTENSIONS[mime_type.to_s] || "bin"}"
      end

      # DownloadError is already descriptive; wrap anything else (network, JSON
      # parse) as a DownloadError so callers only rescue one type.
      def with_download_errors
        yield
      rescue DownloadError
        raise
      rescue StandardError => e
        Rails.logger.error("#{log_prefix} failed: #{e.class}: #{e.message}")
        raise DownloadError, "#{e.class}: #{e.message}"
      end

      def log_prefix
        "Whatsapp::MediaDownloader"
      end
  end
end
