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
      Rails.logger.warn("Vision::PdfTextExtractor failed for #{@file_path}: #{e.class}: #{e.message}")
      ""
    end
  end
end
