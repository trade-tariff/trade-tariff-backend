RSpec.describe RulesOfOrigin::HeadingMappings do
  subject(:mappings) { described_class.new test_file }

  let(:test_file) { file_fixture 'rules_of_origin/rules_to_commodities.csv' }
  let(:imported_mappings) { mappings.tap(&:import) }

  describe '.new' do
    context 'with valid file' do
      it { is_expected.to be_instance_of described_class }
    end

    context 'with missing file' do
      let(:test_file) do
        Rails.root.join(file_fixture_path).join 'rules_of_origin/random.json'
      end

      it { expect { mappings }.to raise_exception described_class::InvalidFile }
    end

    context 'with non-CSV file' do
      let(:test_file) { file_fixture 'rules_of_origin/invalid.json' }

      it { expect { mappings }.to raise_exception described_class::InvalidFile }
    end
  end

  describe '#import' do
    subject { mappings.import }

    it('returns the number of imported rows') { is_expected.to be 97 }

    context 'with rows for different scopes' do
      before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

      it('skips those rows') { is_expected.to be 3 }
    end

    context 'when already imported' do
      it 'raises an exception' do
        expect { imported_mappings.import }.to \
          raise_exception described_class::AlreadyImported
      end
    end
  end

  describe '.for_heading_and_schemes' do
    subject(:rules) do
      imported_mappings.for_heading_and_schemes heading, [scheme_code]
    end

    let(:scheme_code) { 'albania' }
    let(:heading)     { '010121' }

    context 'with known heading and scheme code' do
      it { is_expected.to include 'albania' }
      it { expect(rules['albania']).to include 282_566 }
    end

    context 'with unknown scheme code' do
      let(:scheme_code) { 'unknown' }

      it { is_expected.to eq({}) }
    end

    context 'with unknown heading' do
      let(:heading) { '111111' }

      it { is_expected.to eq({}) }
    end
  end

  describe '#invalid_mappings' do
    subject { mappings.invalid_mappings }

    context 'with valid file' do
      it { is_expected.to be_empty }
    end

    context 'with invalid rows' do
      let(:test_file) { file_fixture 'rules_of_origin/invalid_mappings.csv' }

      context 'with errors in scheme codes' do
        it { is_expected.to include 19 => ['scheme_code: cannot be blank'] }
        it { is_expected.to include 5 => ['scheme_code: invalid format'] }
      end

      context 'with errors in id_rules' do
        it { is_expected.to include 14 => ['id_rule: cannot be blank'] }
        it { is_expected.to include 25 => ['id_rule: is not numeric'] }
      end

      context 'with errors in sub_headings' do
        it { is_expected.to include 9 => ['sub_heading: cannot be blank'] }
        it { is_expected.to include 11 => ['sub_heading: is not numeric'] }
      end
    end
  end
end
