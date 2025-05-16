namespace :api, defaults: { format: 'json' }, path: '/user' do
  scope module: :user do
    resource :user, only: [:show]
  end
end
