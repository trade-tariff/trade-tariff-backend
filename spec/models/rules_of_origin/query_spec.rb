RSpec.describe RulesOfOrigin::Query do
  subject(:query) do
    described_class.new roo_data_set, heading_code, country_code, nil
  end

  include_context 'with fake rules of origin data'

  let(:heading_code) { roo_heading_code }
  let(:country_code) { roo_country_code }
  let(:commodity_code) { "#{roo_heading_code}1010" }

  describe '.new' do
    it { is_expected.to be_instance_of described_class }

    context 'with full commodity code' do
      let(:heading_code) { commodity_code }

      it { is_expected.to be_instance_of described_class }
    end

    context 'with invalid heading code' do
      let(:heading_code) { '1000' }

      it { expect { query }.to raise_exception described_class::InvalidParams }
    end

    context 'with invalid country code' do
      let(:country_code) { 'USA' }

      it { expect { query }.to raise_exception described_class::InvalidParams }
    end
  end

  context 'with heading and country codes' do
    it { is_expected.to have_attributes querying_for_rules?: true }
    it { is_expected.to have_attributes filtering_schemes?: false }

    describe '#rules' do
      subject { query.rules[roo_scheme_code] }

      let(:rule_set) { roo_data_set.rule_set }

      context 'with matching heading and country code' do
        it { is_expected.to include rule_set.rule(rule_set.id_rules.first) }
        it { is_expected.to have_attributes length: 1 }
      end

      context 'with matching commodity code and country code' do
        let(:heading_code) { commodity_code }

        it { is_expected.to include rule_set.rule(rule_set.id_rules.first) }
        it { is_expected.to have_attributes length: 1 }
      end

      context 'with unmatched country code' do
        let(:country_code) { 'RA' }

        it { expect(query.rules).to be_empty }
      end

      context 'with unmatched heading' do
        let(:heading_code) { '011111' }

        it { expect(query.rules).to be_empty }
      end
    end

    describe '#schemes' do
      subject { query.schemes }

      context 'with matching commodity code and country code' do
        let(:heading_code) { commodity_code }

        it { is_expected.to include roo_scheme }
      end

      context 'with schemes matching supplied country code' do
        it { is_expected.to include roo_scheme }
      end

      context 'without schemes matching supplied country code' do
        let(:roo_country_code) { 'RA' }

        it { is_expected.to be_empty }
      end
    end

    describe '#links' do
      subject { query.links }

      it { is_expected.to have_attributes length: 2 }
      it { is_expected.to include roo_scheme.links.first }
    end

    describe '#rule_sets' do
      subject(:scheme_rule_sets) { query.scheme_rule_sets }

      before do
        scheme_set = roo_data_set.scheme_set

        scheme_set.instance_variable_set('@_schemes', schemes)
        scheme_set.instance_variable_set(
          '@_countries',
          scheme_set.send(:build_countries_to_schemes_index),
        )
      end

      let(:schemes) do
        [
          build(:rules_of_origin_scheme, rule_sets:, countries: %w[FR]),
          build(:rules_of_origin_scheme, rule_sets:, countries: %w[FR ES]),
          build(:rules_of_origin_scheme, rule_sets:, countries: %w[ES]),
        ].index_by(&:scheme_code)
      end

      let(:rule_sets) { build_list :rules_of_origin_v2_rule_set, 3, min: '0000000001' }
      let(:heading_code) { rule_sets.second.max.first(6) }

      it { is_expected.to be_instance_of Hash }
      it { is_expected.to include schemes.keys.first }
      it { is_expected.to include schemes.keys.second }
      it { is_expected.not_to include schemes.keys.third }

      context 'with matched rule sets' do
        subject { scheme_rule_sets.values.first.map(&:id) }

        it { is_expected.not_to include rule_sets.first.id }
        it { is_expected.to include rule_sets.second.id }
        it { is_expected.to include rule_sets.third.id }
      end
    end
  end

  context 'without heading or country code' do
    subject(:query) do
      described_class.new roo_data_set, nil, nil, filter
    end

    let(:filter) { nil }

    it { is_expected.to have_attributes schemes: roo_data_set.scheme_set.all_schemes }
    it { is_expected.to have_attributes rules: {} }
    it { is_expected.to have_attributes scheme_rule_sets: {} }
    it { is_expected.to have_attributes querying_for_rules?: false }
    it { is_expected.to have_attributes filtering_schemes?: false }

    context 'with filter' do
      let(:filter) { { 'has_article' => 'duty-drawback' } }

      it { is_expected.to have_attributes rules: {} }
      it { is_expected.to have_attributes scheme_rule_sets: {} }
      it { is_expected.to have_attributes querying_for_rules?: false }
      it { is_expected.to have_attributes filtering_schemes?: true }
    end

    context 'with invalid filter' do
      let(:filter) { 'random' }

      it { expect { query }.to raise_exception described_class::InvalidFilter }
    end

    context 'with unknown filter' do
      let(:filter) { { 'has_heading' => 'something' } }

      it { expect { query }.to raise_exception described_class::InvalidFilter }
    end
  end
end
