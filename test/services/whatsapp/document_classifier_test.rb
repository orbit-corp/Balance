require "test_helper"

class Whatsapp::DocumentClassifierTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  def message_with(content_type:, filename:, message_type:)
    msg = @workspace.whatsapp_messages.create!(
      wamid: "wamid.classify.#{filename}.#{rand(1_000_000)}",
      message_type: message_type, media_id: "m", sent_at: Time.current
    )
    msg.media.attach(io: StringIO.new("dummy"), filename: filename, content_type: content_type)
    msg
  end

  test "reads a PDF via the PDF text extractor and stores an extraction" do
    msg = message_with(content_type: "application/pdf", filename: "r.pdf", message_type: "document")
    text = file_fixture("vision/gtbank_transfer.txt").read

    Vision::PdfTextExtractor.stub :call, text do
      extraction = Whatsapp::DocumentClassifier.call(msg)

      assert extraction.bank_transfer?
      assert_equal 1_000_000, extraction.amount_kobo
      assert_equal text, extraction.raw_text
    end

    assert msg.reload.classified?
  end

  test "reads an image via OCR" do
    msg = message_with(content_type: "image/jpeg", filename: "r.jpg", message_type: "image")
    text = file_fixture("vision/kuda_transfer.txt").read

    Vision::OcrExtractor.stub :call, text do
      extraction = Whatsapp::DocumentClassifier.call(msg)

      assert extraction.bank_transfer?
      assert_equal 80_000, extraction.amount_kobo
    end
  end

  test "marks unrelated image content as not financial" do
    msg = message_with(content_type: "image/jpeg", filename: "r.jpg", message_type: "image")

    Vision::OcrExtractor.stub :call, "just a caption on a random photo" do
      extraction = Whatsapp::DocumentClassifier.call(msg)

      assert extraction.not_financial?
      assert msg.reload.classified?
    end
  end

  test "does not overwrite an extraction the user already recorded" do
    msg = message_with(content_type: "application/pdf", filename: "r.pdf", message_type: "document")
    msg.create_document_extraction!(document_type: :bank_transfer, review_status: :recorded, amount_kobo: 12_345)

    Vision::PdfTextExtractor.stub :call, file_fixture("vision/gtbank_transfer.txt").read do
      Whatsapp::DocumentClassifier.call(msg)
    end

    assert_equal 12_345, msg.document_extraction.reload.amount_kobo # unchanged
  end
end
