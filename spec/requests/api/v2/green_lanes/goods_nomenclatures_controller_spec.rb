require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturesController do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    before do
      allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
    end

    let :make_request do
      get api_green_lanes_goods_nomenclature_path(123_456, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    let :authorization do
      ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
    end

    context 'when the good nomenclature id is found' do
      before do
        create :subheading, goods_nomenclature_item_id: '1234560000', producline_suffix: '80'
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when the good nomenclature id is not found' do
      it { is_expected.to have_http_status(:not_found) }
    end

    context 'when the good nomenclature has applicable measures' do
      before do
        measure1 = create(:measure, measure_generating_regulation_id: 'D0000001', measure_type_id: '400')
        measure2 = create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500')
        subheading = create(:subheading, goods_nomenclature_item_id: '1234560000', producline_suffix: '80')

        allow(subheading).to receive(:applicable_measures).and_return [measure1, measure2]
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when the good nomenclature has applicable measures with categorisation' do
      before do
        measure1 = create(:measure, measure_generating_regulation_id: 'D0000001', measure_type_id: '400')
        measure2 = create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500')
        subheading = create(:subheading, goods_nomenclature_item_id: '1234560000', producline_suffix: '80')

        allow(subheading).to receive(:applicable_measures).and_return [measure1, measure2]

        GreenLanes::Categorisation.load_from_string json_string
      end

      let(:json_string) do
        '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "1000"
        },
        {
          "category": "1",
          "regulation_id": "D0000002",
          "measure_type_id": "500",
          "geographical_area": "1000"
        }]'
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when request on uk service' do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return 'uk'
      end

      it { is_expected.to have_http_status(:not_found) }
    end
  end

  describe 'User authentication' do
    subject(:rendered) { make_request && response }

    before do
      create :subheading, goods_nomenclature_item_id: '1234560000', producline_suffix: '80'
    end

    let :make_request do
      get api_green_lanes_goods_nomenclature_path(123_456, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    context 'when presence of incorrect bearer token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('incorrect token')
      end

      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when absence of bearer token' do
      let(:authorization) { nil }

      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when presence of incorrect ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'incorrect'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when absence of ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when valid ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      before do
        allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
      end

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