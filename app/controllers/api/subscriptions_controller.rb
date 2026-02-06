class Api::SubscriptionsController < ApplicationController
  def provisional
    subscription = Subscription.find_or_initialize_by(
      transaction_id: params[:transaction_id]
    )

    subscription.update!(
      user_id: params[:user_id],
      product_id: params[:product_id],
      status: "pending"
    )

    render json: { status: "ok" }
  end
end
