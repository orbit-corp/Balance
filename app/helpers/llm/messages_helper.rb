module Llm::MessagesHelper
  PROPOSAL_PARTIALS = {
    "account_creation" => "llm/messages/proposals/account_creation",
    "journal_entry" => "llm/messages/proposals/journal_entry"
  }.freeze

  TOOL_LABELS = {
    running: {
      "get_balance_summary" => "Calculating your balance…",
      "list_accounts" => "Checking your accounts…",
      "propose_account" => "Preparing an account proposal…",
      "list_journal_entries" => "Checking posted entries…",
      "propose_reversal" => "Preparing a reversal proposal…",
      "propose_entry" => "Working out the entry…"
    },
    completed: {
      "get_balance_summary" => "Calculated your balance",
      "list_accounts" => "Checked your accounts",
      "propose_account" => "Prepared an account proposal",
      "list_journal_entries" => "Checked posted entries",
      "propose_reversal" => "Prepared a reversal proposal",
      "propose_entry" => "Worked out the entry"
    }
  }.freeze

  def default_model_display_name
    model = RubyLLM.models.find(RubyLLM.config.default_model)
    "Default: #{model.label}"
  rescue RubyLLM::ModelNotFoundError
    "Default: #{RubyLLM.config.default_model}"
  end

  def tool_running_label(tool_name) = TOOL_LABELS[:running][tool_name] || tool_name.to_s.humanize
  def tool_completed_label(tool_name) = TOOL_LABELS[:completed][tool_name] || tool_name.to_s.humanize

  def assistant_content(content)
    html = Commonmarker.to_html(
      content.to_s,
      options: {
        parse: { smart: true },
        render: { hardbreaks: false, unsafe: false }
      }
    )

    sanitize(
      html,
      tags: %w[p br strong em a ul ol li h1 h2 h3 h4 blockquote pre code table thead tbody tr th td hr del],
      attributes: %w[href title class]
    )
  end

  def user_correction_request?(content)
    content.to_s.match?(/\b(undo|reverse|reversal|correct|mistake)\b/i)
  end

  def render_timeline_item(item)
    case item[:type]
    when :message
      render item[:record]
    when :proposal
      render_proposal(item[:record])
    end
  end

  def render_proposal(proposal)
    partial = PROPOSAL_PARTIALS[proposal.proposal_type] || "llm/messages/proposals/#{proposal.proposal_type}"
    render partial, proposal: proposal
  end
end
