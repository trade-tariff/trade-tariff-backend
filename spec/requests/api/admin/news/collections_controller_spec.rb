RSpec.describe Api::Admin::News::CollectionsController do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }

  describe 'GET to #index' do
    let :make_request do
      authenticated_get api_admin_news_collections_path(format: :json)
    end

    context 'with some news collections' do
      before { create_pair :news_collection }

      it_behaves_like 'a successful jsonapi response', 2
    end

    context 'without any news collections' do
      it_behaves_like 'a successful jsonapi response', 0
    end
  end
end
