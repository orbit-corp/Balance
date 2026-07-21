# Minimal spike scope: create one campaign with one channel (any platform) and
# an auto-generated shortlink in a single submit, so the create -> redirect ->
# click round trip can be tested end to end. More channels can be added from
# the campaign page afterwards (CampaignChannelsController).
class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show update]

  TABS = %w[overview analytics conversions].freeze

  def index
    scope = current_workspace.campaigns.includes(campaign_channels: :shortlinks).order(created_at: :desc)
    scope = scope.where("name LIKE ?", "%#{Campaign.sanitize_sql_like(params[:q])}%") if params[:q].present?

    @campaigns = scope.active
    @archived_campaigns = scope.archived
  end

  def new
    @campaign = current_workspace.campaigns.build
  end

  def create
    @campaign = current_workspace.campaigns.build(name: params[:name])

    unless CampaignChannel.platforms.key?(params[:platform])
      @campaign.errors.add(:base, "Pick a platform")
      flash.now[:alert] = "Pick a platform for your first channel."
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @campaign.save!
      CampaignChannel.create_with_default_shortlink!(
        campaign: @campaign,
        platform: params[:platform],
        destination_url: params[:destination_url],
        host: request.host_with_port
      )
    end

    redirect_to campaign_path(@campaign), notice: "Campaign created."
  rescue ActiveRecord::RecordInvalid => e
    @campaign = current_workspace.campaigns.build(name: params[:name])
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @campaign = current_workspace.campaigns.build(name: params[:name])
    flash.now[:alert] = "That link collided with an existing one — try again."
    render :new, status: :unprocessable_entity
  end

  def show
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "overview"
  end

  # Header "More" menu: archive/restore only for now — everything else in
  # that menu (export, bulk QR) is a slice-2+ reserved container, not wired.
  def update
    unless Campaign.statuses.key?(params[:status])
      redirect_to campaign_path(@campaign), alert: "Unrecognized status."
      return
    end

    @campaign.update!(status: params[:status])
    redirect_to campaign_path(@campaign), notice: @campaign.archived? ? "Campaign archived." : "Campaign restored."
  end

  private
    def set_campaign
      @campaign = current_workspace.campaigns.includes(campaign_channels: { shortlinks: :clicks }).find(params[:id])
    end
end
