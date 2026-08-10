class Conversion < ApplicationRecord
  belongs_to :workspace
  belongs_to :shortlink, optional: true
  belongs_to :campaign, optional: true

  enum :kind, { lead: 0, sale: 1 }
  enum :confirmation_status, { self_reported: 0, confirmed: 1 }
  enum :source, { manual: 0, whatsapp_ref_match: 1 }

  validates :amount_kobo, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_at, presence: true
  validate :shortlink_belongs_to_same_workspace
  validate :campaign_belongs_to_same_workspace

  def amount
    return nil if amount_kobo.nil?

    BigDecimal(amount_kobo) / 100
  end

  def amount=(value)
    self.amount_kobo = value.blank? ? nil : (BigDecimal(value.to_s) * 100).round
  end

  def attributed?
    shortlink_id.present?
  end

  private
    def shortlink_belongs_to_same_workspace
      return if shortlink.nil?

      unless shortlink.campaign_channel.campaign.workspace_id == workspace_id
        errors.add(:shortlink, "must belong to the same workspace")
      end
    end

    def campaign_belongs_to_same_workspace
      return if campaign.nil?

      errors.add(:campaign, "must belong to the same workspace") unless campaign.workspace_id == workspace_id
    end
end
