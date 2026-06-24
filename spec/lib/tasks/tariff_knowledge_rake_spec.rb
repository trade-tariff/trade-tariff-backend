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
      tariff_knowledge:note_structures:validate
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
  describe 'tariff_knowledge:note_structures:validate' do
    it 'validates current chapter notes and prints a concise report' do
      update = create(:customs_tariff_update, version: '1.31', validity_start_date: 1.day.ago)
      create(:customs_tariff_update, :failed, version: '1.32', validity_start_date: Time.zone.today)
      note = create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '72', content: '1. Definitions.')
      result = TariffKnowledge::NoteStructureValidator::Result.new(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragment_count: 1,
        event_count: 1,
        root_node_count: 0,
        total_node_count: 0,
        orphan_event_count: 0,
        orphan_event_keys: [],
        duplicate_block_keys: [],
        uncontained_fragment_keys: %w[fragment-key],
        issues: [
          TariffKnowledge::NoteStructureValidator::Issue.new(
            severity: 'warning',
            code: 'uncontained_fragments',
            message: '1 fragments were not contained by any emitted note block',
            details: { 'fragment_keys' => %w[fragment-key] },
          ),
        ],
      )

      allow(TariffKnowledge::NoteStructureValidator).to receive(:call).and_return(result)

      output = capture_output { Rake::Task['tariff_knowledge:note_structures:validate'].invoke }

      expect(TariffKnowledge::NoteStructureValidator).to have_received(:call).with(
        source_type: 'customs_tariff_chapter_note',
        source_id: note.chapter_id,
        source_version: update.version,
        content: note.content,
      )
      expect(output).to include('Validated 1 tariff knowledge note sources')
      expect(output).to include('warning: 1')
      expect(output).to include('uncontained_fragments: 1')
      expect(output).to include('Chapter 72')
    end
  end

  def capture_output
    original_stdout = $stdout
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = original_stdout
  end
end
# rubocop:enable RSpec/DescribeClass
