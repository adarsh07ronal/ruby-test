module Subscriptions
  class StateMachine
    def self.apply(subscription:, event:)
      case event.event_type
      when "PURCHASE"
        activate(subscription, event)
      when "RENEW"
        renew(subscription, event)
      when "CANCEL"
        cancel(subscription)
      else
        raise "Unknown event type: #{event.event_type}"
      end
    end

    private

    def self.activate(subscription, event)
      subscription.update!(
        status: "active",
        current_period_start: event.purchase_date,
        current_period_end: event.expires_date
      )
    end

    def self.renew(subscription, event)
      subscription.update!(
        status: "active",
        current_period_start: event.purchase_date,
        current_period_end: event.expires_date
      )
    end

    def self.cancel(subscription)
      subscription.update!(status: "canceled")
    end
  end
end
