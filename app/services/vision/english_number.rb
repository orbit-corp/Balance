module Vision
  class EnglishNumber
    UNITS = {
      "zero" => 0, "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
      "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10,
      "eleven" => 11, "twelve" => 12, "thirteen" => 13, "fourteen" => 14, "fifteen" => 15,
      "sixteen" => 16, "seventeen" => 17, "eighteen" => 18, "nineteen" => 19,
      "twenty" => 20, "thirty" => 30, "forty" => 40, "fifty" => 50,
      "sixty" => 60, "seventy" => 70, "eighty" => 80, "ninety" => 90
    }.freeze

    SCALES = { "thousand" => 1_000, "million" => 1_000_000, "billion" => 1_000_000_000 }.freeze

    def self.parse(phrase)
      new(phrase).parse
    end

    def initialize(phrase)
      @tokens = phrase.to_s.downcase.scan(/[a-z]+/)
    end

    def parse
      total = 0
      current = 0
      seen = false

      @tokens.each do |token|
        if UNITS.key?(token)
          current += UNITS[token]
          seen = true
        elsif token == "hundred"
          current = (current.zero? ? 1 : current) * 100
          seen = true
        elsif SCALES.key?(token)
          total += (current.zero? ? 1 : current) * SCALES[token]
          current = 0
          seen = true
        elsif token == "and"
          next
        elsif seen
          break
        end
      end

      seen ? total + current : nil
    end
  end
end
