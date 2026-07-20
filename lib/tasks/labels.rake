module LabelsTasks
module_function

  def coverage
    TimeMachine.now do
      print_coverage_stats(coverage_stats)
    end
  end

  def coverage_stats
    total_gn = GoodsNomenclature.actual.non_hidden.with_leaf_column.declarable.count
    total_labels = GoodsNomenclatureLabel.count
    base = GoodsNomenclatureLabel.declarable_nomenclatures

    {
      total_gn:,
      total_labels:,
      coverage: total_gn.positive? ? (total_labels * 100.0 / total_gn).round(2) : 0,
      unlabeled_count: base.where(GoodsNomenclatureLabel.unlabeled).count,
      stale_count: base.where(GoodsNomenclatureLabel.stale_label).count,
      drifted_count: base.where(GoodsNomenclatureLabel.self_text_context_changed).count,
      needing_work: GoodsNomenclatureLabel.goods_nomenclatures_dataset.count,
    }
  end

  def print_coverage_stats(stats)
    puts 'Label Coverage Statistics'
    puts '-' * 30
    puts "Total Declarable GN: #{stats[:total_gn]}"
    puts "Labeled:             #{stats[:total_labels]}"
    puts "Needing work:        #{stats[:needing_work]}"
    puts "  Unlabeled:         #{stats[:unlabeled_count]}"
    puts "  Stale:             #{stats[:stale_count]}"
    puts "  Context drifted:   #{stats[:drifted_count]}"
    puts "Coverage:            #{stats[:coverage]}%"
  end

  def generate
    puts 'Enqueuing label generation...'
    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end

  def load_self_texts
    LabelSelfTextLoader.call
  end

  def relabel
    scope = relabel_scope
    label_sids = scope.select_map(:goods_nomenclature_sid)
    updated = scope.update(stale: true, updated_at: Time.zone.now)
    PaperTrail::BulkVersioning.record_current_versions_for_item_ids!(model: GoodsNomenclatureLabel, item_ids: label_sids) if updated.positive?
    puts "Marked #{updated} labels as stale"

    unlabeled = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count
    puts "#{unlabeled} nodes now need relabeling, enqueuing generation..."

    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end

  def relabel_scope
    scope = GoodsNomenclatureLabel.dataset
    return scope if ENV['CHAPTER'].blank?

    scope.where(Sequel.like(:goods_nomenclature_item_id, "#{ENV['CHAPTER']}%"))
  end

  def status
    require 'json'

    print_busy_relabel_workers
    puts
    print_queued_relabel_workers
  end

  def print_busy_relabel_workers
    puts 'BUSY:'
    Sidekiq::Workers.new.each do |_pid, _tid, work|
      payload = JSON.parse(work.payload)
      next unless payload['class'].include?('Relabel')

      puts "  #{payload['class']} args=#{payload['args']} (running since #{Time.zone.at(work.run_at)})"
    end
  end

  def print_queued_relabel_workers
    queued = Sidekiq::Queue.all.flat_map do |queue|
      queue.select { |job| job.klass.include?('Relabel') }
    end

    puts "QUEUED (#{queued.size}):"
    queued.each do |job|
      puts "  #{job.klass} args=#{job.args} (enqueued #{Time.zone.at(job.enqueued_at)}) [#{job.queue}]"
    end
  end

  def gaps
    LabelGapReporter.call(ENV['CHAPTER'])
  end

  def score
    sids = GoodsNomenclatureLabel.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} labels..."

    scorer = LabelConfidenceScorer.new
    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i

    sids.each_slice(batch_size).with_index do |batch, index|
      scorer.score(batch)
      processed = [(index + 1) * batch_size, sids.size].min
      puts "  #{processed}/#{sids.size} scored"
    end

    puts 'Scoring complete.'
  end

  def nuke_and_regenerate
    LabelRegenerator.call
  end
end

namespace :labels do
  desc 'Show label coverage statistics'
  task(coverage: :environment) { LabelsTasks.coverage }

  desc 'Enqueue label generation for all goods nomenclatures'
  task(generate: :environment) { LabelsTasks.generate }

  desc 'Load and verify CN2026 self-texts'
  task(load_self_texts: :environment) { LabelsTasks.load_self_texts }

  desc 'Mark all labels stale and re-label (CHAPTER=02 to scope by chapter)'
  task(relabel: :environment) { LabelsTasks.relabel }

  desc 'Show busy and queued label generation workers'
  task(status: :environment) { LabelsTasks.status }

  desc 'Show label gaps, stale and context-drifted records by chapter and heading (CHAPTER=XX to filter)'
  task(gaps: :environment) { LabelsTasks.gaps }

  desc 'Score all labels (embed label terms and compare against self-text embeddings)'
  task(score: :environment) { LabelsTasks.score }

  desc 'Delete all labels and regenerate with contextual descriptions'
  task(nuke_and_regenerate: :environment) { LabelsTasks.nuke_and_regenerate }
end
