namespace :harness_eval do
  desc "Run live harness eval cases against the LM Studio model (HARNESS_EVAL_MODEL, HARNESS_EVAL_BASE_URL to override)"
  task :run, [ :case_ids ] => :environment do |_task, args|
    Llm::Harness::LiveRunner.new(
      case_ids: [ args[:case_ids], *args.extras ].compact.map(&:strip).reject(&:blank?),
      model_id: ENV["HARNESS_EVAL_MODEL"],
      base_url: ENV["HARNESS_EVAL_BASE_URL"]
    ).run
  end
end
