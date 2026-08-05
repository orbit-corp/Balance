# Orchestrates the vision layer for one WhatsApp message: reads the attached file
# (PDF via pdf-reader, image via OCR), parses it for bank-transfer fields, and stores
# the result as a WhatsappDocumentExtraction staging record. Nothing here touches the
# ledger — a journal entry is only created later, from the review queue, on user confirm.
module Whatsapp
  class DocumentClassifier
    def self.call(whatsapp_message)
      new(whatsapp_message).call
    end

    def initialize(whatsapp_message)
      @message = whatsapp_message
    end

    def call
      return if @message.media.blank? || !@message.media.attached?

      text = extract_text
      attrs = Vision::BankTransferParser.call(text).merge(raw_text: text)

      extraction = WhatsappDocumentExtraction.find_or_initialize_by(whatsapp_message: @message)
      # Don't clobber an extraction the user has already actioned.
      return extraction unless extraction.review_pending?

      extraction.update!(attrs)
      @message.update!(classification_status: :classified)
      extraction
    end

    private
      def extract_text
        @message.media.blob.open do |file|
          if pdf?
            Vision::PdfTextExtractor.call(file.path)
          elsif image?
            Vision::OcrExtractor.call(file.path)
          else
            ""
          end
        end
      end

      def content_type
        @message.media.content_type.to_s
      end

      def pdf?
        content_type == "application/pdf"
      end

      def image?
        content_type.start_with?("image/")
      end
  end
end
