class UserApi < ::Rails::Engine
end

UserApi.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '' do
    scope module: :user do
      resource :users, only: %i[show update], controller: 'public_users'
      resources :subscriptions, only: %i[show destroy] do
        post :batch, on: :member, action: :create_batch
        resources :subscription_targets, only: %i[index], path: 'targets'
      end
      resources :commodity_changes, only: %i[index show]
      resources :grouped_measure_changes, only: %i[index show]
      resources :grouped_measure_commodity_changes, only: %i[show]
    end
  end
end
