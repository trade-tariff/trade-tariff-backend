require 'rails_helper'

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

    it('will return the number of imported rows') { is_expected.to be 99 }

    context 'with rows for different scopes' do
      before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

      it('will skip those rows') { is_expected.to be 0 }
    end

    context 'when already imported' do
      it 'will raise an exception' do
        expect { imported_mappings.import }.to \
          raise_exception described_class::AlreadyImported
      end
    end
  end
end
