class UserApi < ::Rails::Engine
end

UserApi.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '/user' do
    scope module: :user do
      resource :users, only: %i[show update], controller: 'public_users'
      resources :subscriptions, only: %i[show destroy]
    end
  end
end
