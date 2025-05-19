namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resource :users, only: %i[show update], controller: 'public_users'
  end
end
