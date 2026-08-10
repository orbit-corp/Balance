class CampaignChannelsController < ApplicationController
  def create
    campaign = current_workspace.campaigns.find(params[:campaign_id])

    unless CampaignChannel.platforms.key?(params[:platform])
      redirect_to campaign_path(campaign), alert: "Pick a platform for the new channel."
      return
    end

    CampaignChannel.create_with_default_shortlink!(
      campaign: campaign,
      platform: params[:platform],
      destination_url: params[:destination_url],
      host: request.host_with_port
    )

    redirect_to campaign_path(campaign), notice: "#{helpers.campaign_channel_label(params[:platform])} added."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to campaign_path(campaign), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to campaign_path(campaign), alert: "That link collided with an existing one — try again."
  end
end
