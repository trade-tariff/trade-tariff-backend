RSpec.describe TradeTariffRequest do
  after { described_class.reset }

  describe '.record_search_failure' do
    it 'records each failure once' do
      described_class.record_search_failure(Search::FailureCodes::OPENSEARCH_FAILED)
      described_class.record_search_failure(Search::FailureCodes::OPENSEARCH_FAILED)

      expect(described_class.search_failures).to eq(%w[opensearch_failed])
    end

    it 'rejects unknown codes' do
      expect { described_class.record_search_failure('provider_broke') }
        .to raise_error(ArgumentError, 'Unknown search failure: provider_broke')
    end
  end

  describe '.search_failed?' do
    it 'checks the stable failures recorded for the current request' do
      described_class.record_search_failure(Search::FailureCodes::INTERACTIVE_SEARCH_FAILED)

      expect(described_class.search_failed?(Search::FailureCodes::INTERACTIVE_SEARCH_FAILED)).to be(true)
      expect(described_class.search_failed?(Search::FailureCodes::OPENSEARCH_FAILED)).to be(false)
    end
  end
end
