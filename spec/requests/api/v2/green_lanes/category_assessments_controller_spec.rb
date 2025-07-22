RSpec.describe Api::V2::GreenLanes::CategoryAssessmentsController, :v2 do
  before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

  let(:category_assessments) { create_pair :category_assessment }

  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      api_get api_green_lanes_category_assessments_path(format: :json),
              headers: { 'HTTP_AUTHORIZATION' => authorization }
    end

    let :authorization do
      ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
    end

    before do
      allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'

      category_assessments
    end

    context 'when categorisation data is found' do
      it_behaves_like 'a successful jsonapi response'

      context 'with caching' do
        before do
          freeze_time

          allow(Rails.cache).to receive(:fetch).and_call_original

          make_request
        end

        let :cache_key do
          "category-assessments-for-#{Time.zone.today.to_fs(:db)}-latest-assessment-on-#{Time.zone.now.iso8601}"
        end

        it 'caches the result' do
          expect(Rails.cache).to have_received(:fetch).with(cache_key, expires_in: 24.hours)
        end
      end
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

    let :make_request do
      api_get api_green_lanes_category_assessments_path(format: :json),
              headers: { 'HTTP_AUTHORIZATION' => authorization }
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
