require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::CategorisationsController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      authorization = ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')

      get api_green_lanes_categorisations_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization}
    end

    before do
      stub_const('ENV', {'GREEN_LANES_API_TOKENS' => 'Trade-Tariff-Test'})
      allow(::GreenLanes::Categorisation).to receive(:load_from_file).and_return(::GreenLanes::Categorisation.load_from_file(test_file))
    end

    context 'when categorisation data is found' do
      it_behaves_like 'a successful jsonapi response' do
        let(:test_file) { file_fixture 'green_lanes/categorisations.json' }
      end
    end
  end

  describe 'User authentication' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_green_lanes_categorisations_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization}
    end

    context 'when presence of incorrect token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('incorrect token')
      end

      before do
        stub_const('ENV', {'GREEN_LANES_API_TOKENS' => 'Trade-Tariff-Test'})
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when blank bearer token' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('')
      end

      before do
        stub_const('ENV', {'GREEN_LANES_API_TOKENS' => 'Trade-Tariff-Test'})
      end

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when blank ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      before do
        stub_const('ENV', {'GREEN_LANES_API_TOKENS' => ''})
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
        stub_const('ENV', {'GREEN_LANES_API_TOKENS' => 'Trade-Tariff-Test'})
      end

      it { is_expected.to have_http_status :success }
    end

    context 'when multiple values in ENV VAR' do
      let :authorization do
        ActionController::HttpAuthentication::Token.encode_credentials('second-token')
      end

      before do
        stub_const('ENV', {'GREEN_LANES_API_TOKENS' => 'Trade-Tariff-Test, second-token'})
      end

      it { is_expected.to have_http_status :success }
    end
  end
end
