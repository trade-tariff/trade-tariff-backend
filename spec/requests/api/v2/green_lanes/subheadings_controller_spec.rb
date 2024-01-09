require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::SubheadingsController do
  before do
    allow(ENV).to receive(:[]).and_call_original
  end

  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    before do
      allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return 'Trade-Tariff-Test'
    end

    let :make_request do
      authorization = ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')

      get api_green_lanes_subheading_path(123_456, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
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
  end

  describe 'User authentication' do
    subject(:rendered) { make_request && response }

    before do
      create :subheading, goods_nomenclature_item_id: '1234560000', producline_suffix: '80'
    end

    let :make_request do
      get api_green_lanes_subheading_path(123_456, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    context 'when presence of incorrect token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('incorrect token')
      end

      before do
        allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return 'Trade-Tariff-Test'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when blank bearer token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('')
      end

      before do
        allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return 'Trade-Tariff-Test'
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when blank ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      before do
        allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return ''
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
        allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return 'Trade-Tariff-Test'
      end

      it { is_expected.to have_http_status :success }
    end

    context 'when multiple values in ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('second-token')
      end

      before do
        allow(ENV).to receive(:[]).with('GREEN_LANES_API_TOKENS').and_return 'Trade-Tariff-Test, second-token'
      end

      it { is_expected.to have_http_status :success }
    end
  end
end
