RSpec.describe RulesOfOrigin::DataSet do
  subject { described_class.new scheme_set, rule_set, mappings, scheme_associations }

  let(:rules) do
    build_list :rules_of_origin_rule, 2, scheme_code: scheme_set.schemes.first
  end

  let(:scheme_set) { build :rules_of_origin_scheme_set }
  let(:rule_set) { build :rules_of_origin_rule_set, rules: }
  let(:mappings) { build :rules_of_origin_heading_mappings, rule: rules.first }
  let(:scheme_associations) { build :rules_of_origin_scheme_associations }

  it { is_expected.to respond_to :scheme_set }
  it { is_expected.to respond_to :rule_set }
  it { is_expected.to respond_to :heading_mappings }
  it { is_expected.to respond_to :scheme_associations }

  it { is_expected.to have_attributes(scheme_set:) }
  it { is_expected.to have_attributes(rule_set:) }
  it { is_expected.to have_attributes heading_mappings: mappings }
  it { is_expected.to have_attributes(scheme_associations:) }
end
