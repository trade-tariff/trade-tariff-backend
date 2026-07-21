RSpec.describe 'tariff_knowledge rake tasks' do
  def public_atar_import_result(**overrides)
    TariffKnowledge::PublicAtarRulingImporter::Result.new(**{
      seen_count: 2,
      created_count: 2,
      updated_count: 0,
      failed_count: 0,
      refresh_goods_nomenclature_item_ids: %w[6302100000],
      derived_facts_generated_count: 0,
      derived_facts_empty_count: 0,
      derived_facts_failed_count: 0,
      derived_facts_skipped_count: 0,
    }.merge(overrides))
  end

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

  describe 'tariff_knowledge:atars:preload' do
    it 'imports the public ATAR preload file' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:import_file)
        .and_return(public_atar_import_result)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([1])

      suppress_output { Rake::Task['tariff_knowledge:atars:preload'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:import_file)
      expect(TariffKnowledge::PublicAtarSearchRefresh).to have_received(:call).with(%w[6302100000])
    end

    it 'skips outside UK service mode' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:import_file)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call)

      suppress_output { Rake::Task['tariff_knowledge:atars:preload'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:import_file)
      expect(TariffKnowledge::PublicAtarSearchRefresh).not_to have_received(:call)
    end
  end

  describe 'tariff_knowledge:atars:import' do
    around do |example|
      original_values = {}
      names = %w[ATAR_LIMIT ATAR_MAX_PAGES ATAR_REQUEST_DELAY ATAR_MAX_RETRIES]
      original_values = names.index_with { |name| [ENV.key?(name), ENV[name]] }
      names.each { |name| ENV.delete(name) }

      example.run
    ensure
      original_values.each do |name, (present, value)|
        present ? ENV[name] = value : ENV.delete(name)
      end
    end

    it 'imports public ATAR rulings inline' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call).with(
        limit: nil,
        max_pages: 50,
        request_delay: TariffKnowledge::PublicAtarRulingSource::DEFAULT_REQUEST_DELAY,
        max_retries: TariffKnowledge::PublicAtarRulingSource::DEFAULT_MAX_RETRIES,
      ).and_return(public_atar_import_result(created_count: 1, updated_count: 1))
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call).and_return([1])

      suppress_output { Rake::Task['tariff_knowledge:atars:import'].invoke }

      expect(TariffKnowledge::PublicAtarRulingImporter).to have_received(:call).with(
        limit: nil,
        max_pages: 50,
        request_delay: TariffKnowledge::PublicAtarRulingSource::DEFAULT_REQUEST_DELAY,
        max_retries: TariffKnowledge::PublicAtarRulingSource::DEFAULT_MAX_RETRIES,
      )
      expect(TariffKnowledge::PublicAtarSearchRefresh).to have_received(:call).with(%w[6302100000])
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

    it 'rejects a non-numeric request delay before importing or refreshing search' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call)
      ENV['ATAR_REQUEST_DELAY'] = 'not-a-number'

      expect {
        suppress_output { Rake::Task['tariff_knowledge:atars:import'].invoke }
      }.to raise_error(ArgumentError, 'ATAR_REQUEST_DELAY must be numeric')

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:call)
      expect(TariffKnowledge::PublicAtarSearchRefresh).not_to have_received(:call)
    end

    it 'rejects a negative request delay before importing or refreshing search' do
      allow(TariffKnowledge::PublicAtarRulingImporter).to receive(:call)
      allow(TariffKnowledge::PublicAtarSearchRefresh).to receive(:call)
      ENV['ATAR_REQUEST_DELAY'] = '-0.1'

      expect {
        suppress_output { Rake::Task['tariff_knowledge:atars:import'].invoke }
      }.to raise_error(ArgumentError, 'ATAR_REQUEST_DELAY must be numeric')

      expect(TariffKnowledge::PublicAtarRulingImporter).not_to have_received(:call)
      expect(TariffKnowledge::PublicAtarSearchRefresh).not_to have_received(:call)
    end
  end

  describe 'tariff_knowledge:atars:enqueue' do
    it 'enqueues public ATAR import' do
      allow(ImportPublicAtarRulingsWorker).to receive(:perform_async)

      suppress_output { Rake::Task['tariff_knowledge:atars:enqueue'].invoke }

      expect(ImportPublicAtarRulingsWorker).to have_received(:perform_async)
    end
  end

  describe 'tariff_knowledge:note_structures:validate' do
    def validation_result(issues: [])
      TariffKnowledge::NoteStructureValidator::Result.new(
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
        uncontained_fragment_keys: issues.any? ? %w[fragment-key] : [],
        issues:,
      )
    end

    def uncontained_fragment_issue
      TariffKnowledge::NoteStructureValidator::Issue.new(
        severity: 'warning',
        code: 'uncontained_fragments',
        message: '1 fragments were not contained by any emitted note block',
        details: { 'fragment_keys' => %w[fragment-key] },
      )
    end

    it 'validates current chapter notes and prints a concise report' do
      update = create(:customs_tariff_update, version: '1.31', validity_start_date: 1.day.ago)
      create(:customs_tariff_update, :failed, version: '1.32', validity_start_date: Time.zone.today)
      note = create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '72', content: '1. Definitions.')
      result = validation_result(issues: [uncontained_fragment_issue])

      allow(TariffKnowledge::NoteStructureValidator).to receive(:call).and_return(result)

      expect { Rake::Task['tariff_knowledge:note_structures:validate'].invoke }
        .to output(a_string_including(
                     'Validated 1 tariff knowledge note sources',
                     'warning: 1',
                     'uncontained_fragments: 1',
                     'Chapter 72',
                   )).to_stdout

      expect(TariffKnowledge::NoteStructureValidator).to have_received(:call).with(
        source_type: 'customs_tariff_chapter_note',
        source_id: note.chapter_id,
        source_version: update.version,
        content: note.content,
      )
    end

    it 'aborts when FAIL_ON_ISSUES is true and validation reports issues' do
      update = create(:customs_tariff_update, version: '1.31', validity_start_date: 1.day.ago)
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '72', content: '1. Definitions.')
      result = validation_result(issues: [uncontained_fragment_issue])

      allow(TariffKnowledge::NoteStructureValidator).to receive(:call).and_return(result)
      original_value = ENV.fetch('FAIL_ON_ISSUES', nil)
      ENV['FAIL_ON_ISSUES'] = 'true'

      expect {
        expect { Rake::Task['tariff_knowledge:note_structures:validate'].invoke }
          .to raise_error(SystemExit, /Note structure validation reported issues/)
      }.to output(a_string_including('Validated 1 tariff knowledge note sources')).to_stdout
    ensure
      if original_value
        ENV['FAIL_ON_ISSUES'] = original_value
      else
        ENV.delete('FAIL_ON_ISSUES')
      end
    end
  end
end
