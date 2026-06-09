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
    ].each { |task| Rake::Task[task].reenable if Rake::Task.task_defined?(task) }
  end

  describe 'tariff_knowledge:populate' do
    it 'enqueues the full tariff knowledge graph pipeline' do
      allow(CreateTariffKnowledgeSourceGraphWorker).to receive(:perform_async)
      allow(CreateTariffKnowledgeDeclarableNodesWorker).to receive(:perform_async)
      allow(RefreshTariffKnowledgeCompressedNotesWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:populate'].invoke }

      expect(CreateTariffKnowledgeSourceGraphWorker).to have_received(:perform_async).ordered
      expect(CreateTariffKnowledgeDeclarableNodesWorker).to have_received(:perform_async).ordered
      expect(RefreshTariffKnowledgeCompressedNotesWorker).to have_received(:perform_async).ordered
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
end
# rubocop:enable RSpec/DescribeClass
