RSpec.describe Api::V2::RulesOfOrigin::SchemePresenter do
  subject(:presenter) { described_class.new scheme, rules }

  let(:scheme) { build :rules_of_origin_scheme }

  let(:rules) do
    build_list :rules_of_origin_rule, 3, scheme_code: scheme.scheme_code
  end

  it { is_expected.to be_instance_of described_class }
  it { is_expected.to respond_to :rules }
  it { is_expected.to have_attributes rules: rules }
  it { is_expected.to have_attributes rule_ids: rules.map(&:id_rule) }

  describe '.for_many' do
    subject(:presenters) { described_class.for_many query.schemes, query.rules }

    let(:query) do
      RulesOfOrigin::Query.new(roo_data_set, roo_heading_code, roo_country_code)
    end

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }
    it { expect(presenters[0].rules).to have_attributes length: 1 }
  end
end
