class Click < ApplicationRecord
  belongs_to :shortlink

  def self.daily_series(scope, days: 30)
    since = (days - 1).days.ago.beginning_of_day
    counts = scope.where(occurred_at: since..).group("DATE(occurred_at)").count.transform_keys(&:to_s)

    (0...days).map do |i|
      date = (days - 1 - i).days.ago.to_date
      { date: date.iso8601, clicks: counts[date.iso8601].to_i }
    end
  end
end
