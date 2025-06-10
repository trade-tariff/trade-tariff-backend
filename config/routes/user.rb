namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resource :users, only: %i[show update destroy], controller: 'public_users'
  end
end
