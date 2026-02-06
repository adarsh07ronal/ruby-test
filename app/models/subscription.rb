class Subscription < ApplicationRecord
  STATUSES = %w[pending active canceled expired].freeze

  validates :user_id, presence: true
  validates :transaction_id, presence: true, uniqueness: true
  validates :product_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def can_watch?
    return false if current_period_end.nil?

    (active? || canceled?) && current_period_end > Time.current
  end

  def active?
    status == "active"
  end

  def canceled?
    status == "canceled"
  end
end
