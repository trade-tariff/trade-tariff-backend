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
    csv_path = ENV['CSV_PATH']
    SelfTextLookupService.csv_path = csv_path if csv_path.present?

    puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."
    SelfTextLookupService.reload!
    puts "Loaded #{SelfTextLookupService.count} self-texts"
    print_sample_self_text_lookups
  end

  def print_sample_self_text_lookups
    puts "\nSample lookups:"
    %w[0101210000 0102292100 8471300000].each do |code|
      text = SelfTextLookupService.lookup(code)
      puts "  #{code}: #{text || '(not found)'}"
    end
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
    TimeMachine.now do
      context = label_gap_context
      print_chapter_gap_summary(context)
      print_heading_gap_details(context)
    end
  end

  def label_gap_context
    goods_nomenclatures_table = Sequel[:goods_nomenclatures]
    labels_table = Sequel[:goods_nomenclature_labels]
    self_texts_table = Sequel[:goods_nomenclature_self_texts]
    base = label_gap_base_dataset(goods_nomenclatures_table, labels_table, self_texts_table)
    expressions = label_gap_expressions(labels_table, self_texts_table)
    chapter_stats = label_gap_chapter_stats(base, goods_nomenclatures_table, expressions)

    { goods_nomenclatures_table:, labels_table:, self_texts_table:, base:, expressions:, chapter_stats:, chapter_descs: chapter_descriptions }
  end

  def label_gap_base_dataset(goods_nomenclatures_table, labels_table, self_texts_table)
    base = GoodsNomenclature.actual
      .non_hidden
      .with_leaf_column
      .declarable
      .left_join(:goods_nomenclature_labels, { labels_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })
      .left_join(:goods_nomenclature_self_texts, { self_texts_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })

    return base unless ENV['CHAPTER']

    base.where(Sequel.like(goods_nomenclatures_table[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
  end

  def label_gap_expressions(labels_table, self_texts_table)
    {
      unlabeled: Sequel.expr(labels_table[:goods_nomenclature_sid] => nil),
      stale: Sequel.&({ labels_table[:stale] => true }, { labels_table[:manually_edited] => false }),
      drifted: Sequel.&(
        { labels_table[:manually_edited] => false },
        Sequel.~(self_texts_table[:self_text] => nil),
        Sequel.~(labels_table[:context_hash] => GoodsNomenclatureLabel.self_text_hash(self_texts_table)),
      ),
    }
  end

  def label_gap_chapter_stats(base, goods_nomenclatures_table, expressions)
    base
      .select_group(Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch))
      .select_append { count(Sequel.case([[expressions[:unlabeled], 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[expressions[:stale], 1]], nil)).as(stale) }
      .select_append { count(Sequel.case([[expressions[:drifted], 1]], nil)).as(drifted) }
      .order(:ch)
      .all
  end

  def chapter_descriptions
    Chapter.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |chapter| [chapter.goods_nomenclature_item_id.first(2), chapter.description&.truncate(40)] }
  end

  def print_chapter_gap_summary(context)
    puts 'Label Gaps, Stale and Context-Drifted by Chapter'
    puts '=' * 110
    printf "%-4s %-40s %6s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Drift', 'Work', 'Cov %'
    puts '-' * 110
    context[:chapter_stats].each { |row| print_chapter_gap_row(row, context[:chapter_descs]) }
    print_chapter_gap_total(context[:chapter_stats])
  end

  def print_chapter_gap_row(row, chapter_descs)
    total = row[:total]
    work = row[:missing] + row[:stale] + row[:drifted]
    coverage = total.positive? ? ((total - row[:missing]) * 100.0 / total).round(1) : 0

    printf "%-4s %-40s %6d %6d %6d %6d %6d %6.1f%%\n",
           row[:ch], chapter_descs[row[:ch]] || '?', total, row[:missing], row[:stale], row[:drifted], work, coverage
  end

  def print_chapter_gap_total(chapter_stats)
    totals = chapter_gap_totals(chapter_stats)
    puts '-' * 110
    printf "%-45s %6d %6d %6d %6d %6d %6.1f%%\n",
           'TOTAL', totals[:total], totals[:missing], totals[:stale], totals[:drifted], totals[:work], totals[:coverage]
    puts
  end

  def chapter_gap_totals(chapter_stats)
    total = chapter_stats.sum { |row| row[:total] }
    missing = chapter_stats.sum { |row| row[:missing] }
    stale = chapter_stats.sum { |row| row[:stale] }
    drifted = chapter_stats.sum { |row| row[:drifted] }
    work = missing + stale + drifted
    coverage = total.positive? ? ((total - missing) * 100.0 / total).round(1) : 0

    { total:, missing:, stale:, drifted:, work:, coverage: }
  end

  def print_heading_gap_details(context)
    if gap_chapters(context[:chapter_stats]).any?
      print_headings_with_gaps(context)
    else
      puts 'No gaps found - full coverage, nothing stale or drifted!'
    end
  end

  def gap_chapters(chapter_stats)
    chapter_stats.select { |row| (row[:missing] + row[:stale] + row[:drifted]).positive? }.map { |row| row[:ch] }
  end

  def print_headings_with_gaps(context)
    heading_stats = label_gap_heading_stats(context)
    heading_descs = heading_descriptions

    puts 'Labels Needing Work by Heading'
    puts '=' * 90
    printf "%-6s %-40s %6s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Drift', 'Work'
    puts '-' * 90
    print_heading_gap_rows(heading_stats, context[:chapter_descs], heading_descs)
    puts
    print_commodity_work_rows(context)
  end

  def label_gap_heading_stats(context)
    expressions = context[:expressions]
    needing_work_dataset(context).select_group(
      Sequel.function(:substr, context[:goods_nomenclatures_table][:goods_nomenclature_item_id], 1, 2).as(:ch),
      Sequel.function(:substr, context[:goods_nomenclatures_table][:goods_nomenclature_item_id], 1, 4).as(:hd),
    )
      .select_append { count(Sequel.case([[expressions[:unlabeled], 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[expressions[:stale], 1]], nil)).as(stale) }
      .select_append { count(Sequel.case([[expressions[:drifted], 1]], nil)).as(drifted) }
      .order(:ch, :hd)
      .all
  end

  def needing_work_dataset(context)
    expressions = context[:expressions]
    context[:base].where(expressions[:unlabeled] | expressions[:stale] | expressions[:drifted])
  end

  def heading_descriptions
    Heading.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |heading| [heading.goods_nomenclature_item_id.first(4), heading.description&.truncate(40)] }
  end

  def print_heading_gap_rows(heading_stats, chapter_descs, heading_descs)
    current_ch = nil
    heading_stats.each do |row|
      current_ch = print_heading_chapter(row[:ch], current_ch, chapter_descs)
      work = row[:missing] + row[:stale] + row[:drifted]
      printf "  %-4s %-38s %6d %6d %6d %6d\n",
             row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], row[:drifted], work
    end
  end

  def print_heading_chapter(chapter, current_chapter, chapter_descs)
    return current_chapter if chapter == current_chapter

    puts "-- Chapter #{chapter}: #{chapter_descs[chapter] || '?'} --"
    chapter
  end

  def print_commodity_work_rows(context)
    work_rows = commodity_work_rows(context)

    puts 'All Commodities Needing Work (ordered by item_id, producline_suffix)'
    puts '=' * 120
    printf "%-12s %-4s %-9s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
    puts '-' * 120
    print_commodity_work_row_details(work_rows) if work_rows.any?
    puts '-' * 120
    puts "Total needing work: #{work_rows.size}"
  end

  def commodity_work_rows(context)
    expressions = context[:expressions]
    needing_work_dataset(context).select(
      context[:goods_nomenclatures_table][:goods_nomenclature_sid],
      context[:goods_nomenclatures_table][:goods_nomenclature_item_id],
      context[:goods_nomenclatures_table][:producline_suffix],
      Sequel.case(
        [[expressions[:unlabeled], 'missing'], [expressions[:stale], 'stale'], [expressions[:drifted], 'drifted']],
        'unknown',
      ).as(:reason),
    )
      .order(context[:goods_nomenclatures_table][:goods_nomenclature_item_id], context[:goods_nomenclatures_table][:producline_suffix])
      .all
  end

  def print_commodity_work_row_details(work_rows)
    descriptions = commodity_work_descriptions(work_rows)
    work_rows.each do |row|
      printf "%-12s %-4s %-9s %-80s\n",
             row[:goods_nomenclature_item_id], row[:producline_suffix], row[:reason], descriptions[row[:goods_nomenclature_sid]] || '?'
    end
  end

  def commodity_work_descriptions(work_rows)
    work_sids = work_rows.map { |row| row[:goods_nomenclature_sid] }
    GoodsNomenclature.actual
      .where(goods_nomenclature_sid: work_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }
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
    load_self_texts_for_regeneration
    confirm_regeneration!
    delete_labels
    generate
  end

  def load_self_texts_for_regeneration
    csv_path = ENV['CSV_PATH']
    SelfTextLookupService.csv_path = csv_path if csv_path.present?
    puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."

    unless File.exist?(SelfTextLookupService.csv_path)
      puts "ERROR: Self-texts CSV not found at #{SelfTextLookupService.csv_path}"
      puts 'Set CSV_PATH environment variable or place file at data/CN2026_SelfText_EN_DE_FR.csv'
      exit 1
    end

    SelfTextLookupService.reload!
    puts "Loaded #{SelfTextLookupService.count} self-texts"
  end

  def confirm_regeneration!
    return if ENV['CONFIRM'] == 'true'

    puts "\nWARNING: This will delete ALL existing labels and regenerate them."
    puts 'Set CONFIRM=true to proceed.'
    exit 1
  end

  def delete_labels
    puts "\nDeleting all labels..."
    label_dataset = GoodsNomenclatureLabel.dataset
    deleted_count = label_dataset.count
    PaperTrail::BulkVersioning.record_destroy_versions_for_dataset!(dataset: label_dataset) if deleted_count.positive?
    label_dataset.delete
    puts "Deleted #{deleted_count} labels"
    puts "\nEnqueuing label generation..."
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
