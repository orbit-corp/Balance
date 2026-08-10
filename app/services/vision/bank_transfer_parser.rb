module Vision
  class BankTransferParser
    NAIRA = /₦|\bNGN\b|\bnaira\b/i

    AMOUNT_LABELS    = /\A(?:transaction\s+amount|amount(?:\s+paid|\s+sent)?)\b/i
    FEE_LABELS       = /\A(?:transfer\s+fee|fee|vat|charge|charges|stamp|duty|commission)\b/i
    SENDER_LABELS    = /\A(?:sender|payer|from)(?:\s+details)?\b/i
    RECIPIENT_LABELS = /\A(?:beneficiary|receiver|recipient|payee)(?:\s+details)?\b/i
    REFERENCE_LABELS = /\A(?:transaction\s+reference|reference\s+(?:number|no\.?)|reference|session\s+id|transaction\s+ref)\b/i
    BANK_LABELS      = /\A(?:receiving\s+bank|beneficiary\s+bank|bank\s+name)\b/i
    NARRATION_LABELS = /\A(?:remark|remarks|description|narration|note)\b/i
    DATE_LABELS      = /\A(?:paid\s+on|date\s*&\s*time|transaction\s+date|date)\b/i

    HEADER_NOISE     = /\A(?:transaction\s+details|payment\s+type)\b/i

    ALL_LABELS = [
      AMOUNT_LABELS, FEE_LABELS, SENDER_LABELS, RECIPIENT_LABELS,
      REFERENCE_LABELS, BANK_LABELS, NARRATION_LABELS, DATE_LABELS, HEADER_NOISE
    ].freeze

    AMOUNT_PATTERN = /(\d[\d,]*\.\d{2})/
    NAIRA_GLYPHS = /[₦#¥]|(?<![A-Za-z])[NW](?=\s*\d)/
    FOREIGN_CURRENCY = { "$" => "USD", "€" => "EUR", "£" => "GBP" }.freeze
    NIGERIAN_CONTEXT = /nigeria|\bNDIC\b|microfinance\s+bank|central\s+bank\s+of\s+nigeria/i

    TRANSFER_KEYWORDS = /transfer|transaction|beneficiary|\bsender\b|\breceiver\b|nibss|payment|receipt|successful|debited|credited/i

    OUTWARD_KEYWORDS = /outward|debited|money\s+sent|you\s+sent|transfer\s+to/i
    INWARD_KEYWORDS  = /inward|credited|received\s+from|money\s+received/i

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s
      @lines = @text.split("\n").map(&:strip).reject(&:empty?)
    end

    def call
      currency, currency_supported = detect_currency

      amount_kobo, amount_primary = currency_supported ? extract_amount : [ nil, false ]
      sender_name = value_for(SENDER_LABELS)
      recipient_name = value_for(RECIPIENT_LABELS)
      recipient_bank = value_for(BANK_LABELS)
      reference_number = value_for(REFERENCE_LABELS)
      narration = value_for(NARRATION_LABELS)
      transaction_date = extract_date
      words_match = amount_words_match?(amount_kobo)

      confidence = score(amount_kobo, sender_name, recipient_name, reference_number, transaction_date, words_match)
      document_type = verdict(amount_kobo, sender_name, recipient_name, reference_number)

      {
        document_type: document_type,
        currency: currency,
        currency_supported: currency_supported,
        amount_kobo: amount_kobo,
        direction_guess: extract_direction,
        sender_name: sender_name,
        recipient_name: recipient_name,
        recipient_bank: recipient_bank,
        reference_number: reference_number,
        transaction_date: transaction_date,
        narration: narration,
        confidence: confidence
      }
    end

    private
      attr_reader :text, :lines

      def value_for(label_regex)
        lines.each_with_index do |line, i|
          match = line.match(label_regex)
          next unless match

          inline = line[match[0].length..].to_s.sub(/\A\s*[:\-|]?\s*/, "").strip
          return inline if inline.present? && !label?(inline)

          nxt = lines[(i + 1)..].find { |l| !label?(l) }
          return nxt if nxt.present?
        end
        nil
      end

      def label?(str)
        ALL_LABELS.any? { |re| str.match?(re) }
      end

      def extract_amount
        candidates = []
        lines.each_with_index do |line, i|
          prev = lines[0...i].reverse.find(&:present?)
          fee = FEE_LABELS.match?(line) || (prev && FEE_LABELS.match?(prev))
          primary = AMOUNT_LABELS.match?(line) || (prev && AMOUNT_LABELS.match?(prev))

          compact = line.gsub(/\s+/, "")
          has_symbol = compact.match?(NAIRA_GLYPHS)
          compact.scan(AMOUNT_PATTERN) do |(raw)|
            candidates << { kobo: to_kobo(raw), fee: fee, primary: primary, symbol: has_symbol }
          end
        end

        payable = candidates.reject { |c| c[:fee] }
        return [ nil, false ] if payable.empty?

        ranked = payable.select { |c| c[:primary] }.presence ||
                 payable.select { |c| c[:symbol] }.presence ||
                 payable
        chosen = ranked.max_by { |c| c[:kobo] }
        [ chosen[:kobo], chosen[:primary] ]
      end

      def to_kobo(raw)
        (BigDecimal(raw.delete(",")) * 100).round
      rescue ArgumentError
        0
      end

      def extract_date
        labeled = value_for(DATE_LABELS)
        candidate = labeled || scan_for_date
        return nil if candidate.blank?

        Date.parse(candidate)
      rescue Date::Error
        snippet = scan_for_date(candidate)
        snippet ? (Date.parse(snippet) rescue nil) : nil
      end

      def scan_for_date(source = text)
        source[/\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b/] ||
          source[/\b[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}\b/] ||
          source[/\b\d{1,2}[\/-]\d{1,2}[\/-]\d{4}\b/]
      end

      def extract_direction
        return "outward" if text.match?(OUTWARD_KEYWORDS)
        return "inward" if text.match?(INWARD_KEYWORDS)

        "unknown"
      end

      def detect_currency
        FOREIGN_CURRENCY.each { |sign, code| return [ code, false ] if text.include?(sign) }

        return [ "NGN", true ] if text.match?(NAIRA)
        return [ "NGN", true ] if text.match?(NAIRA_GLYPHS) || text.match?(NIGERIAN_CONTEXT)

        [ nil, false ]
      end

      def amount_words_match?(amount_kobo)
        return false if amount_kobo.nil?

        phrase = text[/([A-Za-z][A-Za-z\s-]*?)\s+naira/i, 1]
        return false if phrase.blank?

        words_value = Vision::EnglishNumber.parse(phrase)
        return false if words_value.nil?

        words_value == (amount_kobo / 100)
      end

      def score(amount, sender, recipient, reference, date, words_match)
        s = 0.0
        s += 0.30 if amount
        s += 0.20 if words_match
        s += 0.20 if recipient.present?
        s += 0.15 if sender.present?
        s += 0.10 if reference.present?
        s += 0.05 if date
        [ s, 1.0 ].min.round(2)
      end

      def verdict(amount, sender, recipient, reference)
        looks_like_transfer = text.match?(TRANSFER_KEYWORDS)
        field_count = [ sender, recipient, reference ].count(&:present?)

        return :not_financial unless looks_like_transfer || amount

        if amount && looks_like_transfer && field_count >= 2
          :bank_transfer
        elsif amount || (looks_like_transfer && field_count >= 1)
          :needs_review
        else
          :not_financial
        end
      end
  end
end
