namespace :harness_eval do
  desc "Evaluate every docs/journal_entry_examples.md transaction and write a harness report"
  task :run, [ :case_ids ] => :environment do |_task, args|
    Llm::Harness::LiveRunner.new(
      case_ids: [ args[:case_ids], *args.extras ].compact.map(&:strip).reject(&:blank?),
      model_id: ENV["HARNESS_EVAL_MODEL"],
      base_url: ENV["HARNESS_EVAL_BASE_URL"]
    ).run
  end
end
