# Extracts embedded text from a PDF using the pure-Ruby pdf-reader gem (no system
# dependency). Forwarded bank PDFs are digitally generated, so their text comes out
# clean without any OCR. Returns "" for an unreadable, encrypted, or image-only PDF
# rather than raising — the classifier treats empty text as "not financial".
require "pdf-reader"

module Vision
  class PdfTextExtractor
    def self.call(file_path)
      new(file_path).call
    end

    def initialize(file_path)
      @file_path = file_path
    end

    def call
      reader = PDF::Reader.new(@file_path)
      reader.pages.map(&:text).join("\n")
    rescue StandardError => e
      # pdf-reader raises a family of errors (malformed/encrypted/unsupported) plus
      # file errors; the contract is to return "" rather than raise.
      Rails.logger.warn("Vision::PdfTextExtractor failed for #{@file_path}: #{e.class}: #{e.message}")
      ""
    end
  end
end
