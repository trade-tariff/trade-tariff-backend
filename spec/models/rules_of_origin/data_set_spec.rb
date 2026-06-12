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

  describe '.load_default' do
    let(:service) { 'uk' }
    let(:scheme_associations_importer) { instance_double(RulesOfOrigin::SchemeAssociations, scheme_associations:) }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
      allow(RulesOfOrigin::SchemeSet).to receive(:from_default_file).with(service).and_return(scheme_set)
      allow(RulesOfOrigin::RuleSet).to receive(:from_default_file).and_return(rule_set)
      allow(RulesOfOrigin::HeadingMappings).to receive(:from_default_file).and_return(mappings)
      allow(RulesOfOrigin::SchemeAssociations).to receive(:from_default_file).and_return(scheme_associations_importer)
      allow(rule_set).to receive(:import)
      allow(mappings).to receive(:import)
    end

    it 'loads the default data set', :aggregate_failures do
      data_set = described_class.load_default

      expect(data_set).to have_attributes(
        scheme_set:,
        rule_set:,
        heading_mappings: mappings,
        scheme_associations:,
      )
      expect(rule_set).to have_received(:import)
      expect(mappings).to have_received(:import).with(skip_invalid_rows: true)
    end
  end
end
