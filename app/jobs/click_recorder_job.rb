class ClickRecorderJob < ApplicationJob
  BOT_PATTERN = /bot|crawl|spider|facebookexternalhit|WhatsApp/i

  def perform(shortlink_id:, ref_code:, ip_address:, user_agent:, referrer:, occurred_at:)
    shortlink = Shortlink.find_by(id: shortlink_id)
    return if shortlink.nil?

    shortlink.clicks.create!(
      ref_code: ref_code,
      ip_address: ip_address,
      user_agent: user_agent,
      referrer: referrer,
      occurred_at: occurred_at,
      bot: user_agent.to_s.match?(BOT_PATTERN)
    )
  end
end
