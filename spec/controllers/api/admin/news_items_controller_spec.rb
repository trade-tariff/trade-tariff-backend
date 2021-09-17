describe Api::Admin::NewsItemsController do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }
  let(:news_item) { create :news_item }

  describe 'GET to #index' do
    render_views

    before { login_as_api_user }

    let(:make_request) { get :index, format: :json }

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
    render_views

    before { login_as_api_user }

    let(:make_request) do
      get :show, format: :json, params: { id: news_item_id }
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
    render_views

    before { login_as_api_user }

    let(:make_request) { post :create, format: :json, params: news_item_data }

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
      it { is_expected.to have_attributes location: api_news_item_url(NewsItem.last.id) }
      it { expect { page_response }.to change(NewsItem, :count).by(1) }
    end

    context 'with invalid params' do
      let(:news_item_attrs) { attributes_for :news_item, title: nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for news item' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(NewsItem, :count) }
    end
  end

  describe 'PATCH to #update' do
    render_views

    before { login_as_api_user }

    let(:news_item_id) { news_item.id }
    let(:updated_title) { 'Updated title' }

    let(:make_request) do
      patch :update, format: :json, params: {
        id: news_item_id,
        data: {
          type: :news_item,
          attributes: { title: updated_title },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes location: api_news_item_url(news_item.id) }
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
    render_views

    before { login_as_api_user }

    let :make_request do
      delete :destroy, format: :json, params: { id: news_item_id }
    end

    context 'with known news item' do
      let(:news_item_id) { news_item.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(news_item, :exists?) }
    end

    context 'with unknown news item' do
      let(:news_item_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(NewsItem, :count) }
    end
  end
end
