namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resource :users, only: [:show], controller: 'public_users'
  end
end
