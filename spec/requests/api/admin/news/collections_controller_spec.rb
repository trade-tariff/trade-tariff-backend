RSpec.describe Api::Admin::News::CollectionsController, :admin do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }

  let(:news_collection) { create :news_collection }

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

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_news_collection_path(news_collection_id, format: :json)
    end

    context 'with existent news collection' do
      let(:news_collection_id) { news_collection.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent news collection' do
      let(:news_collection_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_news_collections_path(format: :json), params: news_collection_data
    end

    let :news_collection_data do
      {
        data: {
          type: :news_collection,
          attributes: news_collection_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:news_collection_attrs) { attributes_for :news_collection }

      it { is_expected.to have_http_status :created }

      it { expect { page_response }.to change(News::Collection, :count).by(1) }
    end

    context 'with invalid params' do
      let(:news_collection_attrs) { attributes_for :news_collection, name: nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for news collection' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(News::Collection, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:news_collection_id) { news_collection.id }
    let(:updated_name) { 'Updated name' }

    let(:make_request) do
      authenticated_patch api_admin_news_collection_path(news_collection_id, format: :json), params: {
        data: {
          type: :news_collection,
          attributes: { name: updated_name },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { expect { page_response }.not_to change(news_collection.reload, :name) }
    end

    context 'with invalid params' do
      let(:updated_name) { '' }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for news collection' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(news_collection.reload, :name) }
    end

    context 'with unknown news collection' do
      let(:news_collection_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(news_collection.reload, :name) }
    end
  end
end
