require "test_helper"

class Vision::EnglishNumberTest < ActiveSupport::TestCase
  test "parses common amount phrases" do
    assert_equal 10_000, Vision::EnglishNumber.parse("Ten Thousand")
    assert_equal 250_000, Vision::EnglishNumber.parse("Two Hundred And Fifty Thousand")
    assert_equal 1_500_000, Vision::EnglishNumber.parse("One Million Five Hundred Thousand")
    assert_equal 42, Vision::EnglishNumber.parse("forty two")
  end

  test "stops at the first non-number word after digits" do
    assert_equal 10_000, Vision::EnglishNumber.parse("Ten Thousand Naira Zero Kobo".split("naira").first)
  end

  test "returns nil when there is no number" do
    assert_nil Vision::EnglishNumber.parse("hello world")
    assert_nil Vision::EnglishNumber.parse("")
  end
end
