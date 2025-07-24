RSpec.describe Api::Admin::News::ItemsController, :admin do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }
  let(:news_item) { create :news_item }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_news_items_path(format: :json)
    end

    context 'with some news items' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response).to include('meta') }
    end

    context 'without any news items' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_news_item_path(news_item_id, format: :json)
    end

    context 'with existent news item' do
      let(:news_item_id) { news_item.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent news item' do
      let(:news_item_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_news_items_path(format: :json), params: news_item_data
    end

    let :news_item_data do
      {
        data: {
          type: :news_item,
          attributes: news_item_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:news_item_attrs) { attributes_for :news_item }

      it { is_expected.to have_http_status :created }
      it { is_expected.to have_attributes location: api_admin_news_item_url(News::Item.last.id) }
      it { expect { page_response }.to change(News::Item, :count).by(1) }
    end

    context 'with invalid params' do
      let(:news_item_attrs) { attributes_for :news_item, title: nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for news item' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(News::Item, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:news_item_id) { news_item.id }
    let(:updated_title) { 'Updated title' }

    let(:make_request) do
      authenticated_patch api_admin_news_item_path(news_item_id, format: :json), params: {
        data: {
          type: :news_item,
          attributes: { title: updated_title },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes location: api_admin_news_item_url(news_item.id) }
      it { expect { page_response }.not_to change(news_item.reload, :title) }
    end

    context 'with invalid params' do
      let(:updated_title) { '' }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for news item' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(news_item.reload, :title) }
    end

    context 'with unknown news item' do
      let(:news_item_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(news_item.reload, :title) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_news_item_path(news_item_id, format: :json)
    end

    context 'with known news item' do
      let(:news_item_id) { news_item.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(news_item, :exists?) }
    end

    context 'with unknown news item' do
      let(:news_item_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(News::Item, :count) }
    end
  end
end
