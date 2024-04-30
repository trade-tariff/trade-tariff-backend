require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturesController do
  before do
    create :category_assessment, measure: gn.measures.first
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
    allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
  end

  let :gn do
    create :goods_nomenclature, :with_measures,
           goods_nomenclature_item_id: '1234560000'
  end

  let(:request_item_id) { gn.goods_nomenclature_item_id.first(6) }

  let :authorization do
    ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
  end

  let :make_request do
    get api_green_lanes_goods_nomenclature_path(request_item_id, format: :json),
        headers: { 'Accept' => 'application/vnd.uktt.v2',
                   'HTTP_AUTHORIZATION' => authorization },
        params:
  end

  let(:params) { {} }

  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    context 'when the good nomenclature id is not found' do
      let(:request_item_id) { '999999' }

      it { is_expected.to have_http_status(:not_found) }
    end

    context 'when the good nomenclature has applicable measures with categorisation' do
      it_behaves_like 'a successful jsonapi response'
    end

    context 'when request on uk service' do
      before { allow(TradeTariffBackend).to receive(:service).and_return 'uk' }

      it { is_expected.to have_http_status(:not_found) }
    end

    context 'when the filter "geographical_area_id" is provided' do
      let(:params) { { filter: { geographical_area_id: 'AU' } } }

      before do
        allow(GreenLanes::FindCategoryAssessmentsService).to receive(:call).and_call_original
      end

      it 'calls FindCategoryAssessmentsService with correct params' do
        make_request

        expect(GreenLanes::FindCategoryAssessmentsService)
          .to have_received(:call)
          .with(gn.applicable_measures, 'AU')
      end
    end
  end

  describe 'User authentication' do
    subject(:rendered) { make_request && response }

    context 'when presence of incorrect bearer token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('incorrect token')
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when absence of bearer token' do
      let(:authorization) { nil }

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when presence of incorrect ENV VAR' do
      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'incorrect'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when absence of ENV VAR' do
      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return nil
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when valid ENV VAR' do
      it { is_expected.to have_http_status :success }
    end

    context 'when multiple values in ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('second-token')
      end

      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test, second-token'
      end

      it { is_expected.to have_http_status :success }
    end
  end
end
