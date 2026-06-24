namespace :tariff_knowledge do
  desc 'Enqueue the full tariff knowledge graph population pipeline'
  task populate: :environment do
    RefreshTariffKnowledgeCompressedNotesWorker.perform_async
    puts 'Enqueued compressed note refresh, including source graph and declarable node loading. Check Sidekiq for progress.'
  end

  namespace :source_graph do
    desc 'Enqueue tariff knowledge source graph loading'
    task enqueue: :environment do
      CreateTariffKnowledgeSourceGraphWorker.perform_async
      puts 'Enqueued source graph loading. Check Sidekiq for progress.'
    end

    desc 'Run tariff knowledge source graph loading inline'
    task run: :environment do
      TariffKnowledge::SourceGraphLoader.call
      puts 'Source graph loading complete.'
    end
  end

  namespace :declarable_nodes do
    desc 'Enqueue tariff knowledge declarable node loading'
    task enqueue: :environment do
      CreateTariffKnowledgeDeclarableNodesWorker.perform_async
      puts 'Enqueued declarable node loading. Check Sidekiq for progress.'
    end

    desc 'Run tariff knowledge declarable node loading inline'
    task run: :environment do
      TariffKnowledge::DeclarableNodeLoader.call
      puts 'Declarable node loading complete.'
    end
  end

  namespace :compressed_notes do
    namespace :refresh do
      desc 'Enqueue tariff knowledge compressed note refresh'
      task enqueue: :environment do
        RefreshTariffKnowledgeCompressedNotesWorker.perform_async
        puts 'Enqueued compressed note refresh. Check Sidekiq for progress.'
      end

      desc 'Run tariff knowledge compressed note refresh inline'
      task run: :environment do
        result = TariffKnowledge::CompressedNoteRefresh.call
        puts "Compressed note refresh complete: #{result.goods_nomenclature_count} current goods nomenclatures, #{result.expired_note_count} expired notes."
      end
    end
  end
  namespace :note_structures do
    print_issue_counts = lambda do |label, values|
      counts = values.tally
      puts "#{label}: none" if counts.empty?
      counts.sort.each { |value, count| puts "#{value}: #{count}" }
    end

    print_report = lambda do |results|
      issues = results.flat_map(&:issues)
      puts "Validated #{results.count} tariff knowledge note sources"
      puts "Issues: #{issues.count}"
      print_issue_counts.call('Severity', issues.map(&:severity))
      print_issue_counts.call('Code', issues.map(&:code))

      issues.first(10).each_with_index do |issue, index|
        result = results.find { |candidate| candidate.issues.include?(issue) }
        puts "#{index + 1}. Chapter #{result.source_id} #{issue.severity}/#{issue.code}: #{issue.message}"
      end
    end

    validate_chapter_notes = lambda do |update|
      TimeMachine.at(Time.current) do
        update.customs_tariff_chapter_notes_dataset.order(:chapter_id).map do |note|
          TariffKnowledge::NoteStructureValidator.call(
            source_type: 'customs_tariff_chapter_note',
            source_id: note.chapter_id,
            source_version: update.version,
            content: note.content,
          )
        end
      end
    end

    desc 'Validate parsed tariff knowledge note structures. Set FAIL_ON_ISSUES=true to fail when issues are reported.'
    task validate: :environment do
      update = TimeMachine.at(Time.current) do
        CustomsTariffUpdate
          .actual
          .exclude(status: CustomsTariffUpdate::FAILED)
          .order(Sequel.desc(:validity_start_date))
          .first
      end
      results = update ? validate_chapter_notes.call(update) : []

      print_report.call(results)
      abort 'Note structure validation reported issues.' if ENV['FAIL_ON_ISSUES'] == 'true' && results.any? { |result| result.issues.any? }
    end
  end
end
