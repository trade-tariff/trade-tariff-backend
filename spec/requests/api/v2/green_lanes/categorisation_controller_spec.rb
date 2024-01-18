require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::CategorisationsController do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_green_lanes_categorisations_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    let :authorization do
      ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
    end

    before do
      allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
      allow(::GreenLanes::Categorisation).to receive(:load_categorisation).and_return(::GreenLanes::Categorisation.load_from_file(test_file))
    end

    context 'when categorisation data is found' do
      it_behaves_like 'a successful jsonapi response' do
        let(:test_file) { file_fixture 'green_lanes/categorisations.json' }
      end
    end

    context 'when request on uk service' do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return 'uk'
      end

      let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

      it { is_expected.to have_http_status(:not_found) }
    end
  end

  describe 'User authentication' do
    subject(:rendered) { make_request && response }

    before do
      allow(::GreenLanes::Categorisation).to receive(:load_categorisation).and_return(::GreenLanes::Categorisation.load_from_file(test_file))
    end

    let :make_request do
      get api_green_lanes_categorisations_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

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
