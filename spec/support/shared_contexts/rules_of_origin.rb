RSpec.shared_context 'with fake rules of origin data' do
  let(:roo_scheme_code) { roo_data_set.scheme_set.schemes.first }
  let(:roo_scheme) { roo_data_set.scheme_set.scheme(roo_scheme_code) }
  let(:roo_country_code) { roo_scheme.countries.first }
  let(:roo_heading_code) { roo_data_set.heading_mappings.heading_codes.first }
  let(:roo_data_set) { build :rules_of_origin_data_set }
end

RSpec.shared_context 'with fake global rules of origin data' do
  include_context 'with fake rules of origin data'

  before do
    allow(TradeTariffBackend).to receive(:rules_of_origin) { roo_data_set }
  end
end
