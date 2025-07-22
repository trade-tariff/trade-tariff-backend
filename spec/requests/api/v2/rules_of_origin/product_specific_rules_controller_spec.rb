RSpec.describe Api::V2::RulesOfOrigin::ProductSpecificRulesController, :v2 do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      api_get api_product_specific_rules_path(commodity, format: :json)
    end
    let(:commodity) { build :commodity }

    it_behaves_like 'a successful jsonapi response'
  end
end
