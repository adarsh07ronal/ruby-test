class Api::Apple::WebhooksController < ApplicationController
  #skip_before_action :verify_authenticity_token

  def receive
    ActiveRecord::Base.transaction do
      subscription = find_or_create_subscription
      event = find_or_create_event(subscription)

      # If event already existed, do nothing (idempotent)
      return head :ok unless event.previously_new_record?

      Subscriptions::StateMachine.apply(
        subscription: subscription,
        event: event
      )
    end

    head :ok
  end

  private

  def find_or_create_subscription
    Subscription.find_or_create_by!(
      transaction_id: params[:transaction_id]
    ) do |s|
      s.user_id = params[:user_id] || "unknown"
      s.product_id = params[:product_id]
      s.status = "pending"
    end
  end

  def find_or_create_event(subscription)
    SubscriptionEvent.find_or_create_by!(
      transaction_id: params[:transaction_id],
      event_type: params[:type],
      purchase_date: params[:purchase_date]
    ) do |e|
      e.subscription = subscription
      e.product_id = params[:product_id]
      e.amount = params[:amount]
      e.currency = params[:currency]
      e.expires_date = params[:expires_date]
    end
  end
end
