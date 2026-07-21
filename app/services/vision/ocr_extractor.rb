# OCRs an image (a forwarded transfer-receipt screenshot) into text using the
# Tesseract engine via rtesseract. Screenshots are sharp digital renders, so a light
# grayscale + contrast pass (mini_magick, already a dependency) meaningfully improves
# accuracy. Returns "" on any failure rather than raising — the classifier treats
# empty text as "not financial".
require "rtesseract"
require "mini_magick"

module Vision
  class OcrExtractor
    def self.call(file_path)
      new(file_path).call
    end

    def initialize(file_path)
      @file_path = file_path
    end

    def call
      prepared = preprocess(@file_path)
      # PSM 4 ("single column of variable-sized text") reads label/value receipt rows
      # in order; the default PSM 3 jumbles the two-column layout of bank receipts.
      RTesseract.new(prepared, psm: 4).to_s.strip
    rescue StandardError => e
      Rails.logger.warn("Vision::OcrExtractor failed for #{@file_path}: #{e.class}: #{e.message}")
      ""
    ensure
      File.delete(prepared) if prepared && prepared != @file_path && File.exist?(prepared)
    end

    private
      # Grayscale + normalized contrast improves OCR on coloured receipt screenshots.
      # Writes a temp PNG; on any imaging failure we fall back to the original file.
      def preprocess(path)
        output = "#{path}.prep.png"
        image = MiniMagick::Image.open(path)
        image.colorspace("Gray")
        image.normalize
        image.write(output)
        output
      rescue StandardError => e
        Rails.logger.warn("Vision::OcrExtractor preprocess skipped for #{path}: #{e.class}: #{e.message}")
        path
      end
  end
end
