RSpec.describe ImportPublicAtarRulingsWorker, type: :worker do
  describe '#perform' do
    it 'delegates to the public ATAR importer' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(TariffKnowledge::PublicAtarRulingImporter::Result.new(seen_count: 1, created_count: 1, updated_count: 0, failed_count: 0))
      allow(Rails.logger).to receive(:info)

      described_class.new.perform('max_pages' => 1, 'request_delay' => 0)

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call).with(max_pages: 1, request_delay: 0)
      expect(Rails.logger).to have_received(:info).with(/Public ATAR import complete/)
    end

    it 'does not import public ATAR rulings for XI service mode' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:call)
      expect(Rails.logger).to have_received(:info).with(/Skipping public ATAR import/)
    end
  end

  describe 'sidekiq options' do
    it 'uses the low priority daily queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:within_1_day)
    end

    it 'uses bounded retries' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end
end
