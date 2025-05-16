namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resources :users, only: [:show]
  end
end
