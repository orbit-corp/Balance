# Encodes non-negative integers into base62 strings (0-9, a-z, A-Z) and back.
module Base62
  ALPHABET = ("0".."9").to_a + ("a".."z").to_a + ("A".."Z").to_a
  BASE = ALPHABET.length

  def self.encode(number)
    unless number.is_a?(Integer) && number >= 0
      raise ArgumentError, "number must be a non-negative integer, got #{number.inspect}"
    end

    return ALPHABET[0] if number.zero?

    digits = []
    while number.positive?
      digits << ALPHABET[number % BASE]
      number /= BASE
    end

    digits.reverse.join
  end

  def self.decode(string)
    string.chars.reduce(0) do |result, char|
      index = ALPHABET.index(char)
      raise ArgumentError, "invalid base62 character: #{char.inspect}" if index.nil?

      (result * BASE) + index
    end
  end
end
