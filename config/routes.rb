Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    # Client -> Server (provisional start)
    resources :subscriptions, only: [] do
      collection do
        post :provisional
      end
    end

    # Apple -> Server (webhook)
    namespace :apple do
      post :webhook, to: "webhooks#receive"
    end
  end
end
