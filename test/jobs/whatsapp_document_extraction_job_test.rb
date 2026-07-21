require "test_helper"

class WhatsappDocumentExtractionJobTest < ActiveJob::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @message = @workspace.whatsapp_messages.create!(
      wamid: "wamid.extjob.1", message_type: "document", media_id: "m", sent_at: Time.current
    )
    @message.media.attach(io: StringIO.new("dummy"), filename: "r.pdf", content_type: "application/pdf")
  end

  test "runs the classifier and stores an extraction" do
    text = file_fixture("vision/gtbank_transfer.txt").read

    Vision::PdfTextExtractor.stub :call, text do
      WhatsappDocumentExtractionJob.perform_now(@message.id)
    end

    assert @message.reload.classified?
    assert @message.document_extraction.bank_transfer?
  end

  test "marks the message classification_failed once retries are exhausted" do
    Vision::PdfTextExtractor.stub :call, ->(_path) { raise "boom" } do
      job = WhatsappDocumentExtractionJob.new(@message.id)
      job.exception_executions = { [ StandardError ].to_s => 2 }
      assert_nothing_raised { job.perform_now }
    end

    assert @message.reload.classification_failed?
  end

  test "does nothing when the message no longer exists" do
    assert_nothing_raised { WhatsappDocumentExtractionJob.perform_now(-1) }
  end
end
