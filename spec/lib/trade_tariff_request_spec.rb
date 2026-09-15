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

  describe '.request_source_for_user_agent' do
    it 'classifies the frontend user agent' do
      expect(described_class.request_source_for_user_agent('TradeTariffFrontend/a4d021c2')).to eq('frontend')
    end

    it 'classifies the admin user agent' do
      expect(described_class.request_source_for_user_agent('TradeTariffAdmin/b1c2d3e4')).to eq('admin')
    end

    it 'classifies the MCP user agent' do
      expect(described_class.request_source_for_user_agent('TradeTariffMcp/c3d4e5f6')).to eq('mcp')
    end

    it 'classifies other user agents as backend_only' do
      expect(described_class.request_source_for_user_agent('curl/8.0.1')).to eq('backend_only')
    end

    it 'classifies a blank user agent as backend_only' do
      expect(described_class.request_source_for_user_agent(nil)).to eq('backend_only')
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
