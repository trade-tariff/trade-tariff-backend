RSpec.describe Api::V2::News::CollectionsController, :v2 do
  describe 'GET #index' do
    subject(:api_response) do
      make_request
      response
    end

    let :make_request do
      api_get api_news_collections_path(format: :json)
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
