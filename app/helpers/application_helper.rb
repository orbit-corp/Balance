module ApplicationHelper
  def format_naira(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: "₦", precision: 2)
  end

  # Matches the channel dot colors from the Campaigns design mockup — one
  # glance at the dot tells you the declared platform, same as the artifact.
  CAMPAIGN_CHANNEL_COLORS = {
    "whatsapp" => "#25D366",
    "instagram" => "#E1306C",
    "facebook" => "#1877F2",
    "tiktok" => "#111827",
    "x" => "#0f0f0f",
    "sms" => "#6b7280",
    "other" => "#9ca3af"
  }.freeze

  CAMPAIGN_CHANNEL_LABELS = {
    "whatsapp" => "WhatsApp",
    "instagram" => "Instagram",
    "facebook" => "Facebook",
    "tiktok" => "TikTok",
    "x" => "X",
    "sms" => "SMS",
    "other" => "Other"
  }.freeze

  def campaign_channel_dot(platform, size: "h-3.5 w-3.5")
    content_tag :span, nil, class: "inline-block flex-none rounded-full #{size}", style: "background:#{CAMPAIGN_CHANNEL_COLORS.fetch(platform, "#9ca3af")}"
  end

  def campaign_channel_label(platform)
    CAMPAIGN_CHANNEL_LABELS.fetch(platform, platform.to_s.titleize)
  end

  def campaign_status_badge(campaign)
    active = campaign.active?
    dot_color = active ? "bg-green-500" : "bg-neutral-400"
    content_tag :span, class: "inline-flex items-center gap-1.5 rounded-full border border-(--color-border) px-2 py-0.5 text-xs font-medium text-neutral-700" do
      content_tag(:span, nil, class: "inline-block h-1.5 w-1.5 rounded-full #{dot_color}") + content_tag(:span, campaign.status.capitalize)
    end
  end
end
