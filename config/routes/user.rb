namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resources :subscriptions, only: [:show]
  end
end
