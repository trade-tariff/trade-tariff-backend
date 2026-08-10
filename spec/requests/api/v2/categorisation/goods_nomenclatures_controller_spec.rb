RSpec.describe Api::V2::Categorisation::GoodsNomenclaturesController, :v2 do
  before do
    TradeTariffRequest.time_machine_now = Time.current
    create :category_assessment, measure: gn.measures.first
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  let :gn do
    create :goods_nomenclature, :with_measures,
           goods_nomenclature_item_id: '1234560000'
  end

  let(:request_item_id) { gn.goods_nomenclature_item_id.first(6) }

  let :make_request do
    api_get api_categorisation_goods_nomenclature_path(request_item_id, format: :json), params:
  end

  let(:params) { {} }

  describe 'GET #show' do
    subject(:api_response) do
      make_request
      response
    end

    context 'when no legacy API key/token is provided' do
      context 'when the good nomenclature has applicable measures with categorisation' do
        it_behaves_like 'a successful jsonapi response'
      end
    end

    context 'when the good nomenclature id is not a subheading' do
      let(:request_item_id) { '1234000000' }

      it { is_expected.to have_http_status(:not_found) }
    end

    context 'when request on uk service' do
      before { allow(TradeTariffBackend).to receive(:service).and_return 'uk' }

      it { is_expected.to have_http_status(:not_found) }
    end
  end
end
