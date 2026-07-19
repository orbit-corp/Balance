require "test_helper"

class LinkingTokenTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "issue_for creates an active token with the expected format" do
    token = LinkingToken.issue_for(@workspace)

    assert token.active?
    assert_match(/\ALINK-[0-9A-Z]{6}\z/, token.token)
    assert_equal @workspace.id, token.workspace_id
  end

  test "issue_for invalidates the workspace's prior active tokens" do
    first = LinkingToken.issue_for(@workspace)
    second = LinkingToken.issue_for(@workspace)

    assert_not first.reload.active?
    assert second.reload.active?
    assert_not_equal first.token, second.token
  end

  test "expired token is excluded from active scope" do
    token = @workspace.linking_tokens.create!(token: "LINK-ABCDEF", expires_at: 1.minute.ago)

    assert_not LinkingToken.active.include?(token)
    assert token.expired?
  end

  test "consume! sets consumed_at and deactivates the token" do
    token = LinkingToken.issue_for(@workspace)

    token.consume!

    assert token.consumed_at.present?
    assert_not token.active?
  end
end
