class WhatsappMediaDownloadJob < ApplicationJob
  retry_on Whatsapp::MediaDownloader::DownloadError, wait: :polynomially_longer, attempts: 5 do |job, error|
    whatsapp_message_id, = job.arguments
    message = WhatsappMessage.find_by(id: whatsapp_message_id)
    next if message.nil?

    Rails.logger.error("WhatsappMediaDownloadJob permanently failed for message #{whatsapp_message_id}: #{error.class}: #{error.message}")
    message.update!(media_status: :failed)
    job.broadcast_message(message)
  end

  def perform(whatsapp_message_id)
    message = WhatsappMessage.find_by(id: whatsapp_message_id)
    return if message.nil?

    media_id = message.media_id
    return if media_id.blank?

    data = Whatsapp::MediaDownloader.call(media_id)

    message.media.attach(io: data[:io], filename: data[:filename], content_type: data[:content_type])
    message.update!(media_status: :downloaded)

    broadcast_message(message)
  end

  def broadcast_message(message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "workspace_#{message.workspace_id}_messages",
      target: ActionView::RecordIdentifier.dom_id(message),
      partial: "messages/message",
      locals: { message: message }
    )
  end
end
