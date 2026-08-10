module CampaignsHelper
  CHANNEL_COLORS = {
    "whatsapp" => "#25D366",
    "instagram" => "#E1306C",
    "facebook" => "#1877F2",
    "tiktok" => "#111827",
    "x" => "#0f0f0f",
    "sms" => "#6b7280",
    "other" => "#9ca3af"
  }.freeze

  CHANNEL_LABELS = {
    "whatsapp" => "WhatsApp",
    "instagram" => "Instagram",
    "facebook" => "Facebook",
    "tiktok" => "TikTok",
    "x" => "X",
    "sms" => "SMS",
    "other" => "Other"
  }.freeze

  def campaign_channel_dot(platform, size: "h-3.5 w-3.5")
    tag.span nil, class: "inline-block flex-none rounded-full #{size}", style: "background:#{CHANNEL_COLORS.fetch(platform, CHANNEL_COLORS['other'])}"
  end

  def campaign_channel_label(platform)
    CHANNEL_LABELS.fetch(platform, platform.to_s.titleize)
  end

  def campaign_status_badge(campaign)
    tag.span class: "inline-flex items-center gap-1.5 rounded-full border border-neutral-200 px-2 py-0.5 text-xs font-medium text-neutral-700" do
      tag.span(nil, class: "inline-block h-1.5 w-1.5 rounded-full #{campaign.active? ? 'bg-green-500' : 'bg-neutral-400'}") +
        tag.span(campaign.status.capitalize)
    end
  end
end
