# rubocop:disable RSpec/DescribeClass
RSpec.describe 'tariff_knowledge rake tasks' do
  after do
    %w[
      tariff_knowledge:populate
      tariff_knowledge:source_graph:enqueue
      tariff_knowledge:source_graph:run
      tariff_knowledge:declarable_nodes:enqueue
      tariff_knowledge:declarable_nodes:run
      tariff_knowledge:compressed_notes:refresh:enqueue
      tariff_knowledge:compressed_notes:refresh:run
      tariff_knowledge:atars:preload
      tariff_knowledge:atars:import
      tariff_knowledge:atars:enqueue
    ].each { |task| Rake::Task[task].reenable if Rake::Task.task_defined?(task) }
  end

  describe 'tariff_knowledge:populate' do
    it 'enqueues the compressed note refresh pipeline' do
      allow(CreateTariffKnowledgeSourceGraphWorker).to receive(:perform_async)
      allow(CreateTariffKnowledgeDeclarableNodesWorker).to receive(:perform_async)
      allow(RefreshTariffKnowledgeCompressedNotesWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:populate'].invoke }

      expect(RefreshTariffKnowledgeCompressedNotesWorker).to have_received(:perform_async)
      expect(CreateTariffKnowledgeSourceGraphWorker).not_to have_received(:perform_async)
      expect(CreateTariffKnowledgeDeclarableNodesWorker).not_to have_received(:perform_async)
    end
  end

  describe 'tariff_knowledge:source_graph:enqueue' do
    it 'enqueues source graph loading' do
      allow(CreateTariffKnowledgeSourceGraphWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:source_graph:enqueue'].invoke }

      expect(CreateTariffKnowledgeSourceGraphWorker).to have_received(:perform_async)
    end
  end

  describe 'tariff_knowledge:source_graph:run' do
    it 'runs source graph loading inline' do
      allow(TariffKnowledge::SourceGraphLoader).to receive(:call)

      suppress_output { Rake::Task['tariff_knowledge:source_graph:run'].invoke }

      expect(TariffKnowledge::SourceGraphLoader).to have_received(:call)
    end
  end

  describe 'tariff_knowledge:declarable_nodes:enqueue' do
    it 'enqueues declarable node loading' do
      allow(CreateTariffKnowledgeDeclarableNodesWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:declarable_nodes:enqueue'].invoke }

      expect(CreateTariffKnowledgeDeclarableNodesWorker).to have_received(:perform_async)
    end
  end

  describe 'tariff_knowledge:declarable_nodes:run' do
    it 'runs declarable node loading inline' do
      allow(TariffKnowledge::DeclarableNodeLoader).to receive(:call)

      suppress_output { Rake::Task['tariff_knowledge:declarable_nodes:run'].invoke }

      expect(TariffKnowledge::DeclarableNodeLoader).to have_received(:call)
    end
  end

  describe 'tariff_knowledge:compressed_notes:refresh:enqueue' do
    it 'enqueues compressed note refresh' do
      allow(RefreshTariffKnowledgeCompressedNotesWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:compressed_notes:refresh:enqueue'].invoke }

      expect(RefreshTariffKnowledgeCompressedNotesWorker).to have_received(:perform_async)
    end
  end

  describe 'tariff_knowledge:compressed_notes:refresh:run' do
    it 'runs compressed note refresh inline' do
      allow(TariffKnowledge::CompressedNoteRefresh)
        .to receive(:call)
        .and_return(TariffKnowledge::CompressedNoteRefresh::Result.new(goods_nomenclature_count: 2, expired_note_count: 1))

      suppress_output { Rake::Task['tariff_knowledge:compressed_notes:refresh:run'].invoke }

      expect(TariffKnowledge::CompressedNoteRefresh).to have_received(:call)
    end
  end

  describe 'tariff_knowledge:atars:preload' do
    it 'imports the public ATAR preload file' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:import_file)
        .and_return(TariffKnowledge::PublicAtarRulingImporter::Result.new(seen_count: 2, created_count: 2, updated_count: 0, failed_count: 0))

      suppress_output { Rake::Task['tariff_knowledge:atars:preload'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:import_file)
    end

    it 'skips outside UK service mode' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:import_file)

      suppress_output { Rake::Task['tariff_knowledge:atars:preload'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:import_file)
    end
  end

  describe 'tariff_knowledge:atars:import' do
    it 'imports public ATAR rulings inline' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
        .and_return(TariffKnowledge::PublicAtarRulingImporter::Result.new(seen_count: 2, created_count: 1, updated_count: 1, failed_count: 0))

      suppress_output { Rake::Task['tariff_knowledge:atars:import'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call)
    end

    it 'rejects invalid numeric options' do
      original_value = ENV.fetch('ATAR_MAX_PAGES', nil)
      ENV['ATAR_MAX_PAGES'] = 'oops'

      expect {
        suppress_output { Rake::Task['tariff_knowledge:atars:import'].invoke }
      }.to raise_error(ArgumentError, /ATAR_MAX_PAGES/)
    ensure
      if original_value
        ENV['ATAR_MAX_PAGES'] = original_value
      else
        ENV.delete('ATAR_MAX_PAGES')
      end
    end
  end

  describe 'tariff_knowledge:atars:enqueue' do
    it 'enqueues public ATAR import' do
      allow(ImportPublicAtarRulingsWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:atars:enqueue'].invoke }

      expect(ImportPublicAtarRulingsWorker).to have_received(:perform_async)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
