require 'rails_helper'

RSpec.describe Api::V2::RulesOfOriginController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:heading_code) { roo_heading_code }
    let(:country_code) { roo_country_code }

    let :make_request do
      get api_rules_of_origin_schemes_path(format: :json),
          params: { heading_code: heading_code, country_code: country_code },
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it { is_expected.to have_http_status :success }
    it { is_expected.to have_attributes media_type: /json/ }

    context 'with respond json' do
      subject { JSON.parse rendered.body }

      it { is_expected.to include 'data' }
      it { is_expected.to include 'included' }
    end

    context 'without match heading' do
      let(:heading_code) { '010101' }

      it { is_expected.to have_http_status :success }
    end

    context 'without matching country' do
      let(:country_code) { 'ES' }

      it { is_expected.to have_http_status :success }
    end
  end
end
