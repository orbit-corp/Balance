# Runs the vision layer over a downloaded WhatsApp attachment: extracts text and
# parses bank-transfer fields into a WhatsappDocumentExtraction staging record.
# Enqueued by WhatsappMediaDownloadJob once media is attached.
#
# Failures here are almost always non-transient (a bad file, unreadable content), so
# we retry only a couple of times to absorb a flaky Active Storage blob read, then
# mark the message classification_failed.
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
