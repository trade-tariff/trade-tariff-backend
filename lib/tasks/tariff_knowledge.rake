module TariffKnowledgeRakeTasks
module_function

  def populate
    RefreshTariffKnowledgeCompressedNotesWorker.perform_async
    puts 'Enqueued compressed note refresh, including source graph and declarable node loading. Check Sidekiq for progress.'
  end

  def enqueue_source_graph
    CreateTariffKnowledgeSourceGraphWorker.perform_async
    puts 'Enqueued source graph loading. Check Sidekiq for progress.'
  end

  def run_source_graph
    TariffKnowledge::SourceGraphLoader.call
    puts 'Source graph loading complete.'
  end

  def enqueue_declarable_nodes
    CreateTariffKnowledgeDeclarableNodesWorker.perform_async
    puts 'Enqueued declarable node loading. Check Sidekiq for progress.'
  end

  def run_declarable_nodes
    TariffKnowledge::DeclarableNodeLoader.call
    puts 'Declarable node loading complete.'
  end

  def enqueue_compressed_notes_refresh
    RefreshTariffKnowledgeCompressedNotesWorker.perform_async
    puts 'Enqueued compressed note refresh. Check Sidekiq for progress.'
  end

  def run_compressed_notes_refresh
    result = TariffKnowledge::CompressedNoteRefresh.call
    puts "Compressed note refresh complete: #{result.goods_nomenclature_count} current goods nomenclatures, #{result.expired_note_count} expired notes."
  end

  def preload_atars
    return unless uk_service?

    result = TariffKnowledge::PublicAtarRulingImporter.import_file
    refreshed_sids = TariffKnowledge::PublicAtarSearchRefresh.call(result.refresh_goods_nomenclature_item_ids)
    puts "Public ATAR preload complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed."
    puts "Public ATAR search refresh complete: #{refreshed_sids.size} goods nomenclatures refreshed or queued."
  end

  def import_atars
    return unless uk_service?

    result = TariffKnowledge::PublicAtarRulingImporter.call(public_atar_import_options)
    refreshed_sids = TariffKnowledge::PublicAtarSearchRefresh.call(result.refresh_goods_nomenclature_item_ids)
    puts "Public ATAR import complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed."
    puts "Public ATAR search refresh complete: #{refreshed_sids.size} goods nomenclatures refreshed or queued."
  end

  def enqueue_atar_import
    return unless uk_service?

    ImportPublicAtarRulingsWorker.perform_async
    puts 'Enqueued public ATAR import. Check Sidekiq for progress.'
  end

  def uk_service?
    return true if TradeTariffBackend.service == 'uk'

    puts 'Skipping public ATAR import outside UK service mode.'
    false
  end

  def public_atar_import_options
    {
      limit: integer_env('ATAR_LIMIT', nil),
      max_pages: integer_env('ATAR_MAX_PAGES', 50),
      request_delay: float_env('ATAR_REQUEST_DELAY', TariffKnowledge::PublicAtarRulingSource::DEFAULT_REQUEST_DELAY),
      max_retries: integer_env('ATAR_MAX_RETRIES', TariffKnowledge::PublicAtarRulingSource::DEFAULT_MAX_RETRIES),
    }
  end

  def integer_env(name, default = nil, min: 1)
    value = ENV.fetch(name, default)
    return if value.blank?

    Integer(value).tap do |integer|
      raise ArgumentError, "#{name} must be at least #{min}" if integer < min
    end
  rescue ArgumentError
    raise ArgumentError, "#{name} must be an integer"
  end

  def float_env(name, default, min: 0.0)
    Float(ENV.fetch(name, default)).tap do |number|
      raise ArgumentError, "#{name} must be at least #{min}" if number < min
    end
  rescue ArgumentError
    raise ArgumentError, "#{name} must be numeric"
  end

  def validate_note_structures
    update = TimeMachine.at(Time.current) do
      CustomsTariffUpdate
        .actual
        .exclude(status: CustomsTariffUpdate::FAILED)
        .order(Sequel.desc(:validity_start_date))
        .first
    end
    results = update ? validate_chapter_notes(update) : []

    print_note_structure_report(results)
    abort 'Note structure validation reported issues.' if ENV['FAIL_ON_ISSUES'] == 'true' && results.any? { |result| result.issues.any? }
  end

  def validate_chapter_notes(update)
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

  def print_note_structure_report(results)
    issues = results.flat_map(&:issues)
    puts "Validated #{results.count} tariff knowledge note sources"
    puts "Issues: #{issues.count}"
    print_issue_counts('Severity', issues.map(&:severity))
    print_issue_counts('Code', issues.map(&:code))

    issues.first(10).each_with_index do |issue, index|
      result = results.find { |candidate| candidate.issues.include?(issue) }
      puts "#{index + 1}. Chapter #{result.source_id} #{issue.severity}/#{issue.code}: #{issue.message}"
    end
  end

  def print_issue_counts(label, values)
    counts = values.tally
    puts "#{label}: none" if counts.empty?
    counts.sort.each { |value, count| puts "#{value}: #{count}" }
  end
end

desc 'Enqueue the full tariff knowledge graph population pipeline'
task 'tariff_knowledge:populate' => :environment do
  TariffKnowledgeRakeTasks.populate
end

desc 'Enqueue tariff knowledge source graph loading'
task 'tariff_knowledge:source_graph:enqueue' => :environment do
  TariffKnowledgeRakeTasks.enqueue_source_graph
end

desc 'Run tariff knowledge source graph loading inline'
task 'tariff_knowledge:source_graph:run' => :environment do
  TariffKnowledgeRakeTasks.run_source_graph
end

desc 'Enqueue tariff knowledge declarable node loading'
task 'tariff_knowledge:declarable_nodes:enqueue' => :environment do
  TariffKnowledgeRakeTasks.enqueue_declarable_nodes
end

desc 'Run tariff knowledge declarable node loading inline'
task 'tariff_knowledge:declarable_nodes:run' => :environment do
  TariffKnowledgeRakeTasks.run_declarable_nodes
end

desc 'Enqueue tariff knowledge compressed note refresh'
task 'tariff_knowledge:compressed_notes:refresh:enqueue' => :environment do
  TariffKnowledgeRakeTasks.enqueue_compressed_notes_refresh
end

desc 'Run tariff knowledge compressed note refresh inline'
task 'tariff_knowledge:compressed_notes:refresh:run' => :environment do
  TariffKnowledgeRakeTasks.run_compressed_notes_refresh
end

desc 'Import public ATAR rulings from the preload file'
task 'tariff_knowledge:atars:preload' => :environment do
  TariffKnowledgeRakeTasks.preload_atars
end

desc 'Import public ATAR rulings from tax.service.gov.uk'
task 'tariff_knowledge:atars:import' => :environment do
  TariffKnowledgeRakeTasks.import_atars
end

desc 'Enqueue public ATAR ruling import'
task 'tariff_knowledge:atars:enqueue' => :environment do
  TariffKnowledgeRakeTasks.enqueue_atar_import
end

desc 'Validate parsed tariff knowledge note structures. Set FAIL_ON_ISSUES=true to fail when issues are reported.'
task 'tariff_knowledge:note_structures:validate' => :environment do
  TariffKnowledgeRakeTasks.validate_note_structures
end
