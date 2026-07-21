require "test_helper"

class WhatsappMediaDownloadJobTest < ActiveJob::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @message = @workspace.whatsapp_messages.create!(
      wamid: "wamid.media.1", message_type: "image", media_id: "media123", sent_at: Time.current
    )
  end

  test "attaches downloaded media to the message" do
    io = StringIO.new("fake-image-bytes")
    Whatsapp::MediaDownloader.stub :call, { io: io, content_type: "image/jpeg", filename: "media123.jpg" } do
      WhatsappMediaDownloadJob.perform_now(@message.id)
    end

    @message.reload
    assert @message.media.attached?
    assert_equal "media123.jpg", @message.media.filename.to_s
    assert_equal "image/jpeg", @message.media.content_type
    assert @message.downloaded?
  end

  test "retries on a transient download failure" do
    Whatsapp::MediaDownloader.stub :call, ->(_media_id) { raise Whatsapp::MediaDownloader::DownloadError, "boom" } do
      assert_enqueued_with(job: WhatsappMediaDownloadJob) do
        perform_enqueued_jobs(only: []) do
          WhatsappMediaDownloadJob.perform_later(@message.id)
        end
      end
    end

    assert_not @message.reload.media.attached?
    assert @message.pending?
  end

  test "marks the message as failed once retries are exhausted" do
    Whatsapp::MediaDownloader.stub :call, ->(_media_id) { raise Whatsapp::MediaDownloader::DownloadError, "boom" } do
      job = WhatsappMediaDownloadJob.new(@message.id)
      job.exception_executions = { [ Whatsapp::MediaDownloader::DownloadError ].to_s => 5 }
      assert_nothing_raised { job.perform_now }
    end

    assert @message.reload.failed?
  end

  test "does nothing when the message no longer exists" do
    assert_nothing_raised do
      WhatsappMediaDownloadJob.perform_now(-1)
    end
  end

  test "enqueues classification for image attachments" do
    Whatsapp::MediaDownloader.stub :call, { io: StringIO.new("bytes"), content_type: "image/jpeg", filename: "m.jpg" } do
      assert_enqueued_with(job: WhatsappDocumentExtractionJob, args: [ @message.id ]) do
        WhatsappMediaDownloadJob.perform_now(@message.id)
      end
    end
  end

  test "enqueues classification for document attachments" do
    doc = @workspace.whatsapp_messages.create!(
      wamid: "wamid.media.doc", message_type: "document", media_id: "d1", sent_at: Time.current
    )
    Whatsapp::MediaDownloader.stub :call, { io: StringIO.new("bytes"), content_type: "application/pdf", filename: "d1.pdf" } do
      assert_enqueued_with(job: WhatsappDocumentExtractionJob, args: [ doc.id ]) do
        WhatsappMediaDownloadJob.perform_now(doc.id)
      end
    end
  end

  test "does not enqueue classification for non-classifiable types" do
    audio = @workspace.whatsapp_messages.create!(
      wamid: "wamid.media.audio", message_type: "audio", media_id: "a1", sent_at: Time.current
    )
    Whatsapp::MediaDownloader.stub :call, { io: StringIO.new("bytes"), content_type: "audio/ogg", filename: "a1.ogg" } do
      assert_no_enqueued_jobs only: WhatsappDocumentExtractionJob do
        WhatsappMediaDownloadJob.perform_now(audio.id)
      end
    end
  end
end
