require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::CategoryAssessmentsController do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
    create(:geographical_area, :with_reference_group_and_members, :with_description)
    create(:geographical_area, :with_reference_group_and_members, :with_description, geographical_area_id: '1008')
    allow(GreenLanes::CategoryAssessment).to receive(:all).and_return(category_assessments)
  end

  let(:category_assessments) { build_pair :category_assessment, geographical_area: }
  let(:geographical_area) { create :geographical_area, :erga_omnes, :with_description }

  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_green_lanes_category_assessments_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2',
                     'HTTP_AUTHORIZATION' => authorization }
    end

    let :authorization do
      ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
    end

    before do
      allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
    end

    context 'when categorisation data is found' do
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

    let :make_request do
      get api_green_lanes_category_assessments_path(format: :json),
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
