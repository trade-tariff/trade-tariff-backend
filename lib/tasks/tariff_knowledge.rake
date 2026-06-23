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

  namespace :semantic_rule_facts do
    desc 'Run semantic rule fact extraction for referenced tariff knowledge note fragments'
    task extract: :environment do
      result = TariffKnowledge::SemanticRuleFactExtraction.call
      puts "Semantic rule fact extraction complete: #{result.fragment_count} fragments, #{result.fact_count} facts, #{result.goods_nomenclature_count} compressed notes refreshed."
    end
  end
end
