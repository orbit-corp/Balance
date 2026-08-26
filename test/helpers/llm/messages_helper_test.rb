require "test_helper"

class Llm::MessagesHelperTest < ActionView::TestCase
  include Llm::MessagesHelper

  test "renders structured assistant Markdown" do
    html = assistant_content(<<~MARKDOWN)
      ## Entry summary

      - **Debit:** Cash
      - **Credit:** Income

      | Account | Amount |
      | --- | ---: |
      | Cash | ₦2,000 |
    MARKDOWN

    assert_includes html, "<h2>Entry summary"
    assert_includes html, "<ul>"
    assert_includes html, "<strong>Debit:</strong>"
    assert_includes html, "<table>"
  end

  test "does not render unsafe model HTML" do
    html = assistant_content("<script>alert('bad')</script>\n\n[unsafe](javascript:alert('bad'))")

    refute_includes html, "<script"
    refute_includes html, "javascript:"
  end
end
