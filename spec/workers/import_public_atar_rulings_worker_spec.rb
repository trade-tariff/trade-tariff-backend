RSpec.describe ImportPublicAtarRulingsWorker, type: :worker do
  def import_result(**overrides)
    TariffKnowledge::PublicAtarRulingImporter::Result.new(**{
      seen_count: 1,
      created_count: 1,
      updated_count: 0,
      failed_count: 0,
      refresh_goods_nomenclature_item_ids: [],
      derived_facts_generated_count: 1,
      derived_facts_empty_count: 0,
      derived_facts_failed_count: 0,
      derived_facts_skipped_count: 0,
    }.merge(overrides))
  end

  describe '#perform' do
    it 'delegates to the public ATAR importer' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(import_result)
      allow(Rails.logger).to receive(:info)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([])

      described_class.new.perform('max_pages' => 1, 'request_delay' => 0)

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call).with(max_pages: 1, request_delay: 0, generate_derived_facts: true)
      expect(TariffKnowledge::PublicAtarSearchRefresh).to have_received(:call).with([])
      expect(Rails.logger).to have_received(:info).with(/Public ATAR import complete/)
      expect(Rails.logger).to have_received(:info).with(/Public ATAR fact generation complete: 1 generated, 0 empty, 0 failed, 0 skipped/)
    end

    it 'refreshes search surfaces for changed ATAR goods nomenclature item ids' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(import_result(created_count: 0, updated_count: 1, refresh_goods_nomenclature_item_ids: %w[6302100000]))
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([1])
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(TariffKnowledge::PublicAtarSearchRefresh).to have_received(:call).with(%w[6302100000])
      expect(Rails.logger).to have_received(:info).with(/1 goods nomenclatures refreshed or queued/)
    end

    it 'generates derived facts during import' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(import_result)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([])
      allow(Rails.logger).to receive(:info)

      described_class.new.perform('generate_derived_facts' => true)

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call).with(generate_derived_facts: true)
    end

    it 'does not let a job option disable derived fact generation' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(import_result)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([])
      allow(Rails.logger).to receive(:info)

      described_class.new.perform('generate_derived_facts' => 'false')

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call).with(generate_derived_facts: true)
    end

    it 'does not import public ATAR rulings for XI service mode' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:call)
      expect(TariffKnowledge::PublicAtarSearchRefresh).not_to have_received(:call)
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
