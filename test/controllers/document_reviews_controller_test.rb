require "test_helper"

class DocumentReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  def create_extraction(workspace: @workspace, **attrs)
    message = workspace.whatsapp_messages.create!(
      wamid: "wamid.review.#{rand(1_000_000)}", message_type: "document", media_id: "m",
      sent_at: Time.current, classification_status: :classified
    )
    message.create_document_extraction!({
      document_type: :bank_transfer, currency: "NGN", currency_supported: true,
      amount_kobo: 80_000, direction_guess: :outward, recipient_name: "Jane Doe",
      reference_number: "REF1", transaction_date: Date.new(2026, 7, 4)
    }.merge(attrs))
  end

  test "index lists pending transfers for the current workspace only" do
    create_extraction(recipient_name: "MineRecipient")
    create_extraction(workspace: workspaces(:bola_shop), recipient_name: "OtherRecipient")

    get document_reviews_path

    assert_response :success
    assert_match "MineRecipient", response.body
    assert_no_match "OtherRecipient", response.body
  end

  test "index excludes already recorded or dismissed extractions" do
    create_extraction(recipient_name: "PendingOne")
    create_extraction(recipient_name: "RecordedOne", review_status: :recorded)
    create_extraction(recipient_name: "DismissedOne", review_status: :dismissed)

    get document_reviews_path

    assert_match "PendingOne", response.body
    assert_no_match "RecordedOne", response.body
    assert_no_match "DismissedOne", response.body
  end

  test "dismiss marks an extraction dismissed" do
    extraction = create_extraction

    patch dismiss_document_review_path(extraction)

    assert_redirected_to document_reviews_path
    assert extraction.reload.review_dismissed?
  end

  test "cannot dismiss another workspace's extraction" do
    extraction = create_extraction(workspace: workspaces(:bola_shop))

    patch dismiss_document_review_path(extraction)

    assert_response :not_found
    assert extraction.reload.review_pending?
  end
end
