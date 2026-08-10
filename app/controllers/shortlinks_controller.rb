class ShortlinksController < ApplicationController
  def create
    campaign = current_workspace.campaigns.find(params[:campaign_id])
    channel = campaign.campaign_channels.find(params[:campaign_channel_id])

    channel.add_shortlink!(label: params[:label], host: request.host_with_port)

    redirect_to campaign_path(campaign), notice: "Link added."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to campaign_path(campaign), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to campaign_path(campaign), alert: "That link collided with an existing one — try again."
  end
end
