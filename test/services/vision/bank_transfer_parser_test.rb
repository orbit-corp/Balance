require "test_helper"

class Vision::BankTransferParserTest < ActiveSupport::TestCase
  def parse(fixture)
    Vision::BankTransferParser.call(file_fixture("vision/#{fixture}").read)
  end

  test "parses a real GTBank transfer PDF's extracted text" do
    result = parse("gtbank_transfer.txt")

    assert_equal :bank_transfer, result[:document_type]
    assert result[:currency_supported]
    assert_equal "NGN", result[:currency]
    assert_equal 1_000_000, result[:amount_kobo] # ₦10,000.00 despite stray spaces in the source
    assert_equal "Enoma Victor Osasenaga", result[:sender_name]
    assert_equal "Happiness Ngozika Chukwuma", result[:recipient_name]
    assert_equal "Opay", result[:recipient_bank]
    assert_equal "000013260713125653000062668947", result[:reference_number]
    assert_equal Date.new(2026, 7, 13), result[:transaction_date]
    assert_equal "outward", result[:direction_guess]
    # Amount-in-words ("Ten Thousand Naira") matches the numeric amount => full confidence.
    assert_in_delta 1.0, result[:confidence], 0.001
  end

  test "picks the transfer amount over fee and VAT lines (Kuda)" do
    result = parse("kuda_transfer.txt")

    assert_equal :bank_transfer, result[:document_type]
    assert_equal 80_000, result[:amount_kobo] # ₦800.00, not the two ₦0.00 fee/VAT lines
    assert_equal "Victor Enoma", result[:sender_name]
    assert_equal "Aishat Ajoke Olagoke", result[:recipient_name]
    assert_equal Date.new(2026, 7, 4), result[:transaction_date]
    assert_equal "outward", result[:direction_guess]
  end

  test "parses real Tesseract OCR output of a Kuda receipt image" do
    # Captured from OCR of the actual TransferReceipt.jpg (PSM 4). The ₦ sign OCRs as
    # "#", the layout is two-column, and fee/VAT lines are present — the hard real case.
    result = parse("kuda_image_ocr.txt")

    assert_equal :bank_transfer, result[:document_type]
    assert result[:currency_supported]
    assert_equal "NGN", result[:currency]
    assert_equal 80_000, result[:amount_kobo] # ₦800.00 recovered despite the "#" misread
    assert_equal "Victor Enoma", result[:sender_name]
    assert_equal "Aishat Ajoke Olagoke", result[:recipient_name]
    assert_equal "090267260704163319708045230343", result[:reference_number]
    assert_equal Date.new(2026, 7, 4), result[:transaction_date]
    assert_equal "outward", result[:direction_guess]
  end

  test "detects a non-Naira document but marks it unsupported and unrecordable" do
    result = parse("usd_transfer.txt")

    assert_not result[:currency_supported]
    assert_equal "USD", result[:currency]
    assert_nil result[:amount_kobo] # no Naira amount to record
  end

  test "classifies unrelated text as not financial" do
    result = parse("not_financial.txt")

    assert_equal :not_financial, result[:document_type]
    assert_nil result[:amount_kobo]
    assert_equal 0.0, result[:confidence]
  end

  test "handles blank input without raising" do
    result = Vision::BankTransferParser.call("")

    assert_equal :not_financial, result[:document_type]
  end
end
