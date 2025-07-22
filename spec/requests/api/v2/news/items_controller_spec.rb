RSpec.describe Api::V2::News::ItemsController, :v2 do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      api_get api_news_items_path(request_params.merge(format: :json))
    end

    let(:request_params) { {} }

    it_behaves_like 'a successful jsonapi response'

    context 'with subsequent page' do
      let(:request_params) { { service: 'uk', page: '3' } }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'with different page size' do
      let(:request_params) { { service: 'uk', per_page: '1' } }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'with a year' do
      let(:request_params) { { year: item.start_date.year } }
      let(:item) { create :news_item }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when filtering by collection' do
      let(:item) { create :news_item }
      let(:collection) { item.collections.first }

      let :make_request do
        api_get api_news_collection_items_path(collection_id:, format: :json)
      end

      context 'with known collection' do
        let(:collection_id) { collection.id }

        it_behaves_like 'a successful jsonapi response'
      end

      context 'with unknown collection' do
        let(:collection_id) { collection.id + 100 }

        it_behaves_like 'a successful jsonapi response'
      end
    end

    context 'for uk pages' do
      let(:request_params) { { service: 'uk' } }

      it_behaves_like 'a successful jsonapi response'

      context 'with only items for home page' do
        let(:request_params) { { service: 'uk', target: 'home' } }

        it_behaves_like 'a successful jsonapi response'
      end

      context 'with only items for updates page' do
        let(:request_params) { { service: 'uk', target: 'updates' } }

        it_behaves_like 'a successful jsonapi response'
      end

      context 'with items for both updates and home page' do
        let(:request_params) { { service: 'uk', target: '' } }

        it_behaves_like 'a successful jsonapi response'
      end
    end

    context 'for xi pages' do
      let(:request_params) { { service: 'xi' } }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'for unknown service pages' do
      let(:request_params) { { service: 'fr' } }

      it_behaves_like 'a successful jsonapi response'
    end
  end

  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:news_item) { create :news_item }

    let :make_request do
      api_get api_news_item_path(news_item.id, format: :json)
    end

    it_behaves_like 'a successful jsonapi response'

    context 'with unknown news item' do
      let :make_request do
        api_get api_news_item_path(9999, format: :json)
      end

      it { is_expected.to have_http_status :not_found }
    end

    context 'with slug' do
      let :make_request do
        api_get api_news_item_path(news_item.slug, format: :json)
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'with an unknown slug' do
      let :make_request do
        api_get api_news_item_path('something-unknown', format: :json)
      end

      it { is_expected.to have_http_status :not_found }
    end

    context 'with unpublished collection' do
      before { news_item.collections.first.update(published: false) }

      it { is_expected.to have_http_status :not_found }
    end

    context 'without collection' do
      before { news_item.remove_collection news_item.collections.first.id }

      let(:news_item) { create :news_item }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
