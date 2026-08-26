module Llm
  module Harness
    # Aggregates per-case results into summary.json and a human-readable
    # report.md: pass rate, category averages, tool statistics, critical failures.
    class ReportBuilder
      CATEGORY_HEADERS = {
        "intent" => "intent", "tool_selection" => "tools", "proposal_quality" => "quality",
        "approval_handling" => "approval", "state_management" => "state", "safety" => "safety",
        "error_handling" => "errors", "final_outcome" => "final"
      }.freeze

      def initialize(entries:, meta:, output_dir:)
        @entries = entries
        @meta = meta
        @output_dir = output_dir
      end

      def call
        @output_dir.join("summary.json").write(JSON.pretty_generate(summary))
        @output_dir.join("report.md").write(markdown)
        summary
      end

      private

      def summary
        {
          "meta" => @meta,
          "totals" => totals,
          "category_averages" => category_averages,
          "tool_stats" => tool_stats,
          "critical_failures" => critical_failures,
          "results" => @entries.map { |entry| entry[:result] }
        }
      end

      def totals
        {
          "cases" => @entries.size,
          "passed" => passes.size,
          "failed" => @entries.size - passes.size,
          "pass_rate" => pass_rate,
          "overall_average" => average_of(@entries) { |entry| entry[:result]["overall"] }
        }
      end

      def passes
        @passes ||= @entries.select { |entry| entry[:result]["verdict"] == "PASS" }
      end

      def pass_rate
        return 0.0 if @entries.empty?

        (passes.size.to_f / @entries.size * 100).round(1)
      end

      def category_averages
        Scorer::CATEGORIES.index_with do |category|
          average_of(@entries) { |entry| entry[:result]["scores"].fetch(category) }
        end
      end

      def average_of(entries)
        return 0.0 if entries.empty?

        (entries.sum { |entry| yield(entry).to_f } / entries.size).round(2)
      end

      def tool_stats
        events = @entries.flat_map { |entry| entry[:capture]["recorded_tool_events"] }
        events.group_by { |event| event["tool"] }.sort_by { |tool, _| tool }.map do |tool, grouped|
          durations = grouped.pluck("duration_ms").compact
          {
            "tool" => tool,
            "calls" => grouped.size,
            "errors" => grouped.count { |event| event["error"] },
            "avg_duration_ms" => durations.empty? ? nil : (durations.sum.to_f / durations.size).round
          }
        end
      end

      def critical_failures
        @entries.reject { |entry| entry[:result]["verdict"] == "PASS" }.map do |entry|
          weak = entry[:result]["scores"].select { |_, score| score < 8 }
          {
            "case_id" => entry[:result]["case_id"],
            "overall" => entry[:result]["overall"],
            "note" => entry[:result]["note"],
            "weak_categories" => weak
          }
        end
      end

      def markdown
        <<~REPORT
          # Harness Eval Report

          #{meta_lines}

          ## Totals

          - Cases: #{@entries.size}
          - Pass rate: #{pass_rate}% (#{passes.size}/#{@entries.size})
          - Overall average: #{totals['overall_average']}

          ## Category averages

          #{category_table}

          ## Per-case results

          #{per_case_table}

          ## Tool stats

          #{tool_table}

          ## Critical failures

          #{failures_section}
        REPORT
      end

      def meta_lines
        @meta.map { |key, value| "- #{key.tr('_', ' ')}: #{value}" }.join("\n")
      end

      def category_table
        rows = category_averages.map { |category, avg| "| #{category} | #{avg} |" }
        ([ "| category | avg |", "| --- | --- |" ] + rows).join("\n")
      end

      def per_case_table
        header = "| case | expected outcome | #{Scorer::CATEGORIES.map { |c| CATEGORY_HEADERS.fetch(c) }.join(' | ')} | overall | verdict |"
        divider = "| #{'--- | ' * (Scorer::CATEGORIES.size + 4)}"
        rows = @entries.map do |entry|
          result = entry[:result]
          scores = Scorer::CATEGORIES.map { |category| result["scores"].fetch(category) }
          "| #{result['case_id']} | #{result['outcome_expected']} | #{scores.join(' | ')} | #{result['overall']} | #{result['verdict']} |"
        end
        ([ header, divider ] + rows).join("\n")
      end

      def tool_table
        return "_no tool calls recorded_" if tool_stats.empty?

        header = "| tool | calls | errors | avg ms |"
        divider = "| --- | --- | --- | --- |"
        rows = tool_stats.map do |stats|
          "| #{stats['tool']} | #{stats['calls']} | #{stats['errors']} | #{stats['avg_duration_ms'] || '—'} |"
        end
        ([ header, divider ] + rows).join("\n")
      end

      def failures_section
        failures = critical_failures
        return "_none — all cases passed_" if failures.empty?

        failures.map do |failure|
          "### #{failure['case_id']} (overall #{failure['overall']})\n\n#{failure['note']}"
        end.join("\n\n")
      end
    end
  end
end
