require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "accepts only workspaces available through membership" do
    user = users(:one)

    assert user.sessions.build(workspace: workspaces(:ada_store)).valid?
    refute user.sessions.build(workspace: workspaces(:bola_shop)).valid?
  end
end
