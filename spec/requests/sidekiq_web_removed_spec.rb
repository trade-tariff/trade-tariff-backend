require 'rails_helper'

RSpec.describe 'Sidekiq Web', type: :request do
  it 'is not mounted at /sidekiq' do
    get '/sidekiq'

    expect(response).to have_http_status(:not_found)
  end

  it 'is not mounted at the service path' do
    get "/#{TradeTariffBackend.service}/sidekiq"

    expect(response).to have_http_status(:not_found)
  end
end
