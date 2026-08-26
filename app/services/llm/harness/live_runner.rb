module Llm
  module Harness
    # Orchestrates a full live evaluation: config overrides, corpus loading,
    # sequential case execution against the real pipeline, artifact writing,
    # and aggregate reporting.
    #
    #   bin/rails "harness_eval:run[cash-expense,fraud-refusal]"
    #   HARNESS_EVAL_MODEL=qwen3-30b HARNESS_EVAL_BASE_URL=http://127.0.0.1:1234/v1 \
    #     bin/rails harness_eval:run
    class LiveRunner
      CORPUS_PATHS = %w[
        test/fixtures/files/ledger_harness_cases.json
        test/fixtures/files/ledger_harness_live_cases.json
      ].freeze

      def initialize(case_ids: [], model_id: nil, base_url: nil)
        @case_ids = case_ids
        @requested_model = model_id.presence || RubyLLM.config.default_model
        @requested_base_url = base_url.presence
        $stdout.sync = true
      end

      def run
        apply_config_overrides!
        @llm_model = resolve_llm_model!
        cases = load_cases
        output_dir = prepare_artifacts

        meta = build_meta(cases, @llm_model)
        puts "harness_eval: model=#{@requested_model} base=#{RubyLLM.config.openai_api_base} cases=#{cases.size} dir=#{output_dir}"

        entries = cases.each_with_index.map do |test_case, index|
          execute_one(test_case, output_dir, "#{index + 1}/#{cases.size}")
        end

        summary = ReportBuilder.new(entries: entries, meta: meta, output_dir: output_dir).call
        print_summary(summary, output_dir)
        summary
      end

      private

      def apply_config_overrides!
        RubyLLM.config.openai_api_base = @requested_base_url if @requested_base_url
        RubyLLM.config.default_model = @requested_model
      end

      def resolve_llm_model!
        Llm::Model.find_by(provider: "openai", model_id: @requested_model) ||
          Llm::Model.create!(provider: "openai", model_id: @requested_model, name: @requested_model)
      end

      def load_cases
        all = CORPUS_PATHS.filter_map do |relative|
          path = Rails.root.join(relative)
          JSON.parse(path.read) if path.exist?
        end

        seen = {}
        merged = all.flatten.reject do |test_case|
          id = test_case.fetch("id")
          if seen.key?(id)
            warn "harness_eval: duplicate case id #{id.inspect} in #{seen[id]}; keeping first"
            true
          else
            seen[id] = "earlier corpus"
            false
          end
        end

        return merged.select { |test_case| @case_ids.include?(test_case.fetch("id")) } if @case_ids.any?

        merged
      end

      def prepare_artifacts
        dir = Rails.root.join(
          "tmp/harness_eval/#{Time.current.utc.strftime('%Y%m%d-%H%M%S')}-#{@requested_model.gsub(/[^a-z0-9.-]/i, '_')}"
        )
        FileUtils.mkdir_p([ dir.join("transcripts"), dir.join("results") ])
        dir
      end

      def execute_one(test_case, output_dir, progress)
        case_id = test_case.fetch("id")
        print "harness_eval: #{progress} #{case_id} ... "

        capture = CaseExecutor.new(
          test_case: test_case,
          llm_model: @llm_model,
          run_label: run_label,
          transcript_path: output_dir.join("transcripts/#{case_id}.jsonl")
        ).call
        result = Scorer.new(test_case: test_case, capture: capture).result

        write_result(output_dir, case_id, test_case, capture, result)
        puts "#{result['verdict']} (#{result['overall']})"

        { case: test_case, capture: json_capture(capture), result: result }
      rescue StandardError => e
        puts "ERROR #{e.class}: #{e.message}"
        {
          case: test_case,
          capture: {},
          result: {
            "case_id" => case_id, "outcome_expected" => test_case.dig("expected", "outcome"),
            "scores" => Scorer::CATEGORIES.index_with { 0 }, "overall" => 0.0, "verdict" => "FAIL",
            "note" => "executor crashed: #{e.class}: #{e.message}", "observed" => {}
          }
        }
      end

      def write_result(output_dir, case_id, test_case, capture, result)
        output_dir.join("results/#{case_id}.json").write(
          JSON.pretty_generate("case" => test_case, "capture" => json_capture(capture), "result" => result)
        )
      end

      def json_capture(capture)
        jsonable = capture.dup
        jsonable[:proposals_created] = capture[:proposals_created].map do |proposal|
          { "id" => proposal.id, "type" => proposal.proposal_type, "status" => proposal.status,
            "version" => proposal.version, "data" => proposal.data }
        end
        deep_stringify(jsonable)
      end

      def deep_stringify(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, deep_stringify(item) ] }
        when Array then value.map { |item| deep_stringify(item) }
        else value
        end
      end

      def build_meta(cases, llm_model)
        {
          "started_at_utc" => Time.current.utc.iso8601,
          "model" => llm_model.model_id,
          "provider" => llm_model.provider,
          "base_url" => RubyLLM.config.openai_api_base,
          "requested_base_url_override" => @requested_base_url || "none",
          "ruby_version" => RUBY_VERSION,
          "rails_version" => Rails.version,
          "git_sha" => git_sha,
          "corpus_files" => CORPUS_PATHS.select { |path| Rails.root.join(path).exist? },
          "case_count" => cases.size
        }
      end

      def git_sha
        `git rev-parse --short HEAD`.strip
      rescue StandardError
        "unknown"
      end

      def run_label
        Time.current.utc.strftime("%Y%m%d-%H%M%S")
      end

      def print_summary(summary, output_dir)
        totals = summary["totals"]
        puts <<~SUMMARY
          harness_eval: done — pass #{totals['passed']}/#{totals['cases']} (#{totals['pass_rate']}%), overall avg #{totals['overall_average']}
          harness_eval: report #{output_dir.join('report.md')}
        SUMMARY
      end
    end
  end
end
