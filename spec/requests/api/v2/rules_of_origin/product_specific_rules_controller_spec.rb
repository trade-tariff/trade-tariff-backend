require 'rails_helper'

RSpec.describe Api::V2::RulesOfOrigin::ProductSpecificRulesController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_product_specific_rules_path(commodity, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    let(:commodity) { build :commodity }

    it_behaves_like 'a successful jsonapi response'
  end
end
