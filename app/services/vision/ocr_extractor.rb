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
      RTesseract.new(prepared, psm: 4).to_s.strip
    rescue StandardError => e
      Rails.logger.warn("Vision::OcrExtractor failed for #{@file_path}: #{e.class}: #{e.message}")
      ""
    ensure
      File.delete(prepared) if prepared && prepared != @file_path && File.exist?(prepared)
    end

    private
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
