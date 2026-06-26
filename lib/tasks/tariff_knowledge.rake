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

  namespace :atars do
    ensure_uk_service = lambda do
      next true if TradeTariffBackend.service == 'uk'

      puts 'Skipping public ATAR import outside UK service mode.'
      false
    end
    integer_env = lambda do |name, default = nil, min: 1|
      value = ENV.fetch(name, default)
      return if value.blank?

      Integer(value).tap do |integer|
        raise ArgumentError, "#{name} must be at least #{min}" if integer < min
      end
    rescue ArgumentError
      raise ArgumentError, "#{name} must be an integer"
    end
    float_env = lambda do |name, default, min: 0.0|
      Float(ENV.fetch(name, default)).tap do |number|
        raise ArgumentError, "#{name} must be at least #{min}" if number < min
      end
    rescue ArgumentError
      raise ArgumentError, "#{name} must be numeric"
    end

    desc 'Import public ATAR rulings from the preload file'
    task preload: :environment do
      next unless ensure_uk_service.call

      result = TariffKnowledge::PublicAtarRulingImporter.import_file
      puts "Public ATAR preload complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed."
    end

    desc 'Import public ATAR rulings from tax.service.gov.uk'
    task import: :environment do
      next unless ensure_uk_service.call

      result = TariffKnowledge::PublicAtarRulingImporter.call(
        limit: integer_env.call('ATAR_LIMIT', nil),
        max_pages: integer_env.call('ATAR_MAX_PAGES', 50),
        request_delay: float_env.call('ATAR_REQUEST_DELAY', TariffKnowledge::PublicAtarRulingSource::DEFAULT_REQUEST_DELAY),
        max_retries: integer_env.call('ATAR_MAX_RETRIES', TariffKnowledge::PublicAtarRulingSource::DEFAULT_MAX_RETRIES),
      )
      puts "Public ATAR import complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed."
    end

    desc 'Enqueue public ATAR ruling import'
    task enqueue: :environment do
      next unless ensure_uk_service.call

      ImportPublicAtarRulingsWorker.perform_async
      puts 'Enqueued public ATAR import. Check Sidekiq for progress.'
    end
  end
end
