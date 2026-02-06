class SubscriptionEvent < ApplicationRecord
  EVENT_TYPES = %w[PURCHASE RENEW CANCEL].freeze

  belongs_to :subscription, optional: true

  validates :transaction_id, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
end
