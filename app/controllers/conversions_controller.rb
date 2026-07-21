# Path A of the conversion loop (manual mark) — the seller tells Stubby which
# link (or "I don't know") produced a sale. Path B (auto-matched from a
# forwarded WhatsApp ref tag) surfaces as a pre-selected suggestion on the same
# form; see Campaign#recent_ref_match and Whatsapp::MessageProcessor.
class ConversionsController < ApplicationController
  def create
    campaign = current_workspace.campaigns.find(params[:campaign_id])

    shortlink = nil
    if params[:shortlink_id].present?
      shortlink = campaign.shortlinks.find_by(id: params[:shortlink_id])
      if shortlink.nil?
        redirect_to campaign_path(campaign), alert: "That link isn't part of this campaign."
        return
      end
    end

    # Source is derived server-side from whether the chosen link matches the
    # most recent WhatsApp ref-tag hit for this campaign — never trusted from
    # the client — so a seller can't (even accidentally) claim an auto-match.
    suggested = shortlink && campaign.recent_ref_match&.matched_shortlink_id == shortlink.id

    conversion = current_workspace.conversions.build(
      campaign: campaign,
      shortlink: shortlink,
      kind: params[:kind],
      occurred_at: Time.current,
      source: suggested ? :whatsapp_ref_match : :manual
    )
    conversion.amount = params[:amount]

    if conversion.save
      redirect_to campaign_path(campaign), notice: "Sale recorded."
    else
      redirect_to campaign_path(campaign), alert: conversion.errors.full_messages.to_sentence
    end
  end
end
