class Accounting::PostingService
  Result = Data.define(:entry, :errors, :proof) do
    def success? = errors.empty?
  end

  def self.call(entry:, engine: Accounting::Engine)
    new(entry, engine: engine).call
  end

  def initialize(entry, engine:)
    @entry = entry
    @engine = engine
  end

  def call
    engine_result = nil

    JournalEntry.transaction do
      engine_result = engine.check(entry.journal_entry_lines)
      unless engine_result.ok?
        entry.valid?
        engine_result.errors.each do |message|
          entry.errors.add(:base, message) unless entry.errors[:base].include?(message)
        end
        raise ActiveRecord::Rollback
      end

      entry.save!
    end

    result(engine_result&.proof)
  rescue ActiveRecord::RecordInvalid
    result(engine_result&.proof)
  end

  private

  attr_reader :entry, :engine

  def result(proof)
    Result.new(entry, entry.errors.full_messages.freeze, proof)
  end
end
