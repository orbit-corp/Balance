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
      render_campaign_form_error
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
    render_campaign_form_error
  rescue ActiveRecord::RecordNotUnique
    @campaign = current_workspace.campaigns.build(name: params[:name])
    flash.now[:alert] = "That link collided with an existing one — try again."
    render_campaign_form_error
  end

  def show
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "overview"
  end

  def update
    unless Campaign.statuses.key?(params[:status])
      redirect_to campaign_path(@campaign), alert: "Unrecognized status."
      return
    end

    @campaign.update!(status: params[:status])
    redirect_to campaign_path(@campaign), notice: @campaign.archived? ? "Campaign archived." : "Campaign restored."
  end

  private
    def render_campaign_form_error
      render :new, status: :unprocessable_content
    end

    def set_campaign
      @campaign = current_workspace.campaigns.includes(campaign_channels: { shortlinks: :clicks }).find(params[:id])
    end
end
