module Llm::MessagesHelper
  PROPOSAL_PARTIALS = {
    "journal_entry" => "llm/messages/proposals/journal_entry"
  }.freeze

  TOOL_LABELS = {
    running: {
      "list_accounts" => "Checking your accounts…",
      "propose_entry" => "Working out the entry…"
    },
    completed: {
      "list_accounts" => "Checked your accounts",
      "propose_entry" => "Worked out the entry"
    }
  }.freeze

  def default_model_display_name
    "Default: #{RubyLLM.models.find(RubyLLM.config.default_model).label}"
  end

  def tool_running_label(tool_name) = TOOL_LABELS[:running][tool_name] || tool_name.to_s.humanize
  def tool_completed_label(tool_name) = TOOL_LABELS[:completed][tool_name] || tool_name.to_s.humanize

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
