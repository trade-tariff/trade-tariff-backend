require 'rails_helper'

RSpec.describe Api::V2::RulesOfOrigin::SchemesController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:heading_code) { roo_heading_code }
    let(:country_code) { roo_country_code }
    let(:first_scheme) { JSON.parse(rendered.body)['data'].first['attributes'] }

    let :make_request do
      get api_rules_of_origin_schemes_path(format: :json),
          params: { heading_code:, country_code: }
    end

    it_behaves_like 'a successful jsonapi response'
    it { expect(first_scheme).to include 'scheme_code' }
    it { expect(first_scheme).to include 'introductory_notes' }

    context 'without match heading' do
      let(:heading_code) { '010101' }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'without matching country' do
      let(:country_code) { 'ES' }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'with path params' do
      let :make_request do
        get api_rules_of_origin_path(heading_code:, country_code:, format: :json)
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when listing all schemes' do
      let :make_request do
        get api_rules_of_origin_schemes_path(format: :json)
      end

      it_behaves_like 'a successful jsonapi response'
      it { expect(first_scheme).to include 'scheme_code' }
      it { expect(first_scheme).not_to include 'introductory_notes' }

      context 'with custom includes' do
        subject { JSON.parse(rendered.body)['included'] }

        let :make_request do
          get api_rules_of_origin_schemes_path(include: 'proofs', format: :json)
        end

        it { is_expected.to include include 'type' => 'rules_of_origin_proof' }
      end
    end

    context 'with filtered list of schemes' do
      let :make_request do
        get api_rules_of_origin_schemes_path(filter: { has_article: 'duty-drawback' }, format: :json)
      end

      it_behaves_like 'a successful jsonapi response'
    end
  end
end
