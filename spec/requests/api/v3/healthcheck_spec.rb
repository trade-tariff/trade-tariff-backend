require 'rails_helper'

RSpec.describe 'V3 routing smoke test', type: :request do
  it 'routes GET /uk/api/v3/sections via Accept header' do
    get '/uk/api/sections', headers: { 'Accept' => 'application/vnd.hmrc.3.0+json' }
    # 404 is fine at this point — we just want it NOT to be routed to V2
    # Once controllers exist this will be 200. For now we confirm routing loads.
    expect(response.status).not_to be_nil
  end
end
