RSpec.describe RulesOfOrigin::RuleSet do
  subject(:rule_set) { described_class.new test_file }

  let(:test_file) { file_fixture 'rules_of_origin/rules_of_origin_210728.csv' }
  let(:imported_rules) { rule_set.tap(&:import) }

  describe '.new' do
    context 'with valid file' do
      it { is_expected.to be_instance_of described_class }
    end

    context 'with missing file' do
      let(:test_file) do
        Rails.root.join(file_fixture_path).join 'rules_of_origin/random.json'
      end

      it { expect { rule_set }.to raise_exception described_class::InvalidFile }
    end

    context 'with non-CSV file' do
      let(:test_file) { file_fixture 'rules_of_origin/invalid.json' }

      it { expect { rule_set }.to raise_exception described_class::InvalidFile }
    end
  end

  describe '#import' do
    subject { rule_set.import }

    it('returns the number of imported rows') { is_expected.to be 54 }

    context 'with rows for different scopes' do
      before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

      it('skips those rows') { is_expected.to be 3 }
    end

    context 'when already imported' do
      it 'raises an exception' do
        expect { imported_rules.import }.to \
          raise_exception described_class::AlreadyImported
      end
    end
  end

  describe '#rule' do
    subject { imported_rules.rule(id_rule) }

    context 'with known rule' do
      let(:id_rule) { 20_000_001 }

      it { is_expected.to be_instance_of RulesOfOrigin::Rule }
      it { is_expected.to have_attributes(id_rule:) }
    end

    context 'with unknown rule' do
      let(:id_rule) { 1 }

      it { is_expected.to be_nil }
    end
  end

  describe '#rules_for_ids' do
    subject(:rules) { imported_rules.rules_for_ids(id_rules) }

    let(:id_rules) { [20_000_001, 1] }

    context 'with mix of known and unknown rules' do
      it { is_expected.to be_instance_of Array }
      it { is_expected.to all be_instance_of RulesOfOrigin::Rule }
      it { is_expected.to have_attributes length: 1 }
      it { expect(rules.first).to have_attributes id_rule: 20_000_001 }
    end
  end

  describe '#invalid_rules' do
    subject { imported_rules.invalid_rules }

    context 'with valid file' do
      it { is_expected.to be_empty }
    end

    context 'with invalid rows' do
      let(:test_file) { file_fixture 'rules_of_origin/invalid_rules.csv' }

      it { is_expected.to include have_attributes(id_rule: 20_000_011) }
    end
  end
end
