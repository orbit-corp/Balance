class WhatsappDocumentExtractionJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 2 do |job, error|
    whatsapp_message_id, = job.arguments
    message = WhatsappMessage.find_by(id: whatsapp_message_id)
    next if message.nil?

    Rails.logger.error("WhatsappDocumentExtractionJob permanently failed for message #{whatsapp_message_id}: #{error.class}: #{error.message}")
    message.update!(classification_status: :classification_failed)
  end

  def perform(whatsapp_message_id)
    message = WhatsappMessage.find_by(id: whatsapp_message_id)
    return if message.nil?
    return unless message.media.attached?

    Whatsapp::DocumentClassifier.call(message)
    message.reload

    Turbo::StreamsChannel.broadcast_replace_to(
      "workspace_#{message.workspace_id}_messages",
      target: ActionView::RecordIdentifier.dom_id(message),
      partial: "messages/message",
      locals: { message: message }
    )
  end
end
