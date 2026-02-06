class Subscription < ApplicationRecord
  STATUSES = %w[pending active canceled expired].freeze

  validates :user_id, presence: true
  validates :transaction_id, presence: true, uniqueness: true
  validates :product_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
