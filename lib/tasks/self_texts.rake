module SelfTextsCoverageTasks
module_function

  def coverage
    TimeMachine.now { print_coverage_stats(coverage_stats) }
  end

  def coverage_stats
    total_gn = GoodsNomenclature.actual.non_hidden.count - Chapter.actual.count
    total_self_texts = GoodsNomenclatureSelfText.count
    missing = total_gn - total_self_texts
    stale = GoodsNomenclatureSelfText.where(stale: true).count

    {
      total_gn:,
      total_self_texts:,
      missing:,
      stale:,
      needing_work: missing + stale,
      coverage: total_gn.positive? ? (total_self_texts * 100.0 / total_gn).round(2) : 0,
      by_type: GoodsNomenclatureSelfText.group_and_count(:generation_type).order(:generation_type).all,
    }
  end

  def print_coverage_stats(stats)
    puts 'Self-Text Coverage Statistics'
    puts '-' * 30
    puts "Total GN (excl. chapters): #{stats[:total_gn]}"
    puts "With self-text:            #{stats[:total_self_texts]}"
    puts "Missing:                   #{stats[:missing]}"
    puts "Coverage:                  #{stats[:coverage]}%"
    puts "Stale:                     #{stats[:stale]}"
    puts "Needing work:              #{stats[:needing_work]}"
    puts
    puts 'By generation type:'
    stats[:by_type].each { |row| puts "  #{row[:generation_type]}: #{row[:count]}" }
  end
end

module SelfTextsGenerationTasks
module_function

  def regenerate
    dataset = GoodsNomenclatureSelfText.where(stale: false, manually_edited: false)
    item_ids = dataset.select_map(:goods_nomenclature_sid)
    count = dataset.update(stale: true)
    PaperTrail::BulkVersioning.record_current_versions_for_item_ids!(model: GoodsNomenclatureSelfText, item_ids:) if count.positive?
    puts "Marked #{count} self-texts as stale."

    GenerateSelfTextWorker.perform_async
    puts 'Enqueued regeneration. Check Sidekiq for progress.'
  end

  def generate
    if ENV['CHAPTER']
      generate_chapter
    else
      enqueue_generation
    end
  end

  def generate_chapter
    chapter = TimeMachine.now { Chapter.actual.by_code(ENV['CHAPTER']).take }
    raise "Chapter #{ENV['CHAPTER']} not found" unless chapter

    puts "Generating self-texts for chapter #{ENV['CHAPTER']}..."
    ai = GenerateSelfText::OtherSelfTextBuilder.call(chapter)
    non_other_ai = GenerateSelfText::NonOtherSelfTextBuilder.call(chapter)
    puts "Other AI: #{ai.inspect}"
    puts "Non-Other AI: #{non_other_ai.inspect}"
  end

  def enqueue_generation
    puts 'Enqueuing self-text generation for all chapters...'
    GenerateSelfTextWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end
end

module SelfTextsEuReferenceTasks
module_function

  def populate_eu_references
    require 'csv'

    csv_path = Rails.root.join('data/CN2026_SelfText_EN_DE_FR.csv')
    missing_csv!(csv_path) unless File.exist?(csv_path)

    stats = { updated: 0, skipped_no_match: 0, skipped_blank: 0 }
    CSV.foreach(csv_path, headers: true) { |row| populate_eu_reference(row, stats) }
    puts "EU references populated: #{stats[:updated]} updated, #{stats[:skipped_no_match]} no matching generated text, #{stats[:skipped_blank]} blank"
  end

  def missing_csv!(csv_path)
    puts "CSV not found at #{csv_path}"
    exit 1
  end

  def populate_eu_reference(row, stats)
    code = row['CN_CODE']
    eu_text = row['SelfText_EN']&.strip

    return stats[:skipped_blank] += 1 if code.blank? || eu_text.blank?

    normalized = code.gsub(/\s/, '').ljust(10, '0')
    dataset = eu_reference_update_dataset(normalized, eu_text)
    item_ids = dataset.select_map(:goods_nomenclature_sid)
    count = dataset.update(eu_self_text: eu_text, eu_embedding: nil)
    PaperTrail::BulkVersioning.record_current_versions_for_item_ids!(model: GoodsNomenclatureSelfText, item_ids:) if count.positive?
    update_eu_reference_stats(stats, normalized, count)
  end

  def eu_reference_update_dataset(normalized, eu_text)
    GoodsNomenclatureSelfText
      .where(goods_nomenclature_item_id: normalized)
      .where(Sequel.|({ eu_self_text: nil }, Sequel.~(eu_self_text: eu_text)))
  end

  def update_eu_reference_stats(stats, normalized, count)
    if count.positive?
      stats[:updated] += count
    else
      existing = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: normalized).count
      stats[:skipped_no_match] += 1 if existing.zero?
    end
  end
end

module SelfTextsEmbeddingTasks
module_function

  def generate_embeddings
    service = EmbeddingService.new
    generated = embedding_records(:embedding, :self_text, :self_text)
    puts "Pass 1: #{generated.size} generated self-texts need embeddings..."
    generate_embedding_batches(service, generated, :embedding, :self_text, 'Generated')

    eu_references = embedding_records(:eu_embedding, :eu_self_text, :eu_self_text)
    puts "Pass 2: #{eu_references.size} EU references need embeddings..."
    generate_embedding_batches(service, eu_references, :eu_embedding, :eu_self_text, 'EU')
    puts 'Embedding generation complete.'
  end

  def embedding_records(embedding_column, text_column, select_text_column)
    GoodsNomenclatureSelfText
      .where(embedding_column => nil)
      .exclude(text_column => nil)
      .select(:goods_nomenclature_sid, select_text_column)
      .all
  end

  def generate_embedding_batches(service, records, embedding_column, text_column, label)
    records.each_slice(EmbeddingService::BATCH_SIZE).with_index do |batch, index|
      embeddings = service.embed_batch(batch.map { |record| record.public_send(text_column) })
      update_embeddings(batch, embeddings, embedding_column)
      processed = [(index + 1) * EmbeddingService::BATCH_SIZE, records.size].min
      puts "  #{label}: #{processed}/#{records.size} embedded"
    end
  end

  def update_embeddings(batch, embeddings, embedding_column)
    batch.zip(embeddings).each do |record, embedding|
      update_dataset = GoodsNomenclatureSelfText.where(goods_nomenclature_sid: record.goods_nomenclature_sid)
      update_dataset.update(embedding_column => Sequel.lit("'[#{embedding.join(',')}]'::vector"))
      PaperTrail::BulkVersioning.record_current_versions_for_dataset!(model: GoodsNomenclatureSelfText, dataset: update_dataset)
    end
  end
end

module SelfTextsCleanupTasks
module_function

  def fix_encoding_artefacts
    sanitiser = GenerateSelfText::EncodingArtefactSanitiser
    fixed = 0

    GoodsNomenclatureSelfText.where(generation_type: %w[ai ai_non_other]).each do |record|
      fixed += fix_encoding_artefact(record, sanitiser)
    end

    puts "Done. Fixed #{fixed} records."
  end

  def fix_encoding_artefact(record, sanitiser)
    sanitised = sanitiser.call(record.self_text)
    return 0 if sanitised == record.self_text

    record.update(self_text: sanitised, embedding: nil, search_embedding: nil, search_embedding_stale: true)
    puts "Fixed [#{record.goods_nomenclature_item_id}] sid=#{record.goods_nomenclature_sid}: #{record.self_text.truncate(80)}"
    1
  end

  def score
    sids = GoodsNomenclatureSelfText.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} self-texts..."
    SelfTextConfidenceScorer.new.score(sids)
    puts 'Scoring complete.'
  end
end

module SelfTextsStatusTasks
module_function

  def status
    require 'json'

    TimeMachine.now do
      print_busy_self_text_workers
      puts
      print_queued_self_text_workers
    end
  end

  def print_busy_self_text_workers
    puts 'BUSY:'
    Sidekiq::Workers.new.each do |_pid, _tid, work|
      payload = JSON.parse(work.payload)
      next unless payload['class'].include?('SelfText')

      puts "  #{chapter_label(payload['args']&.first)} (running since #{Time.zone.at(work.run_at)})"
    end
  end

  def print_queued_self_text_workers
    queued = Sidekiq::Queue.all.flat_map { |queue| queue.select { |job| job.klass.include?('SelfText') } }
    puts "QUEUED (#{queued.size}):"
    queued.each do |job|
      puts "  #{chapter_label(job.args&.first)} (enqueued #{Time.zone.at(job.enqueued_at)}) [#{job.queue}]"
    end
  end

  def chapter_label(sid)
    chapter = Chapter.where(goods_nomenclature_sid: sid).first
    chapter ? "#{chapter.goods_nomenclature_item_id.first(2)} - #{chapter.description}" : "sid=#{sid}"
  end
end

module SelfTextsGapTasks
module_function

  def gaps
    TimeMachine.now do
      context = SelfTextsGapSummaryTasks.gap_context
      SelfTextsGapSummaryTasks.print_gap_chapter_summary(context)
      SelfTextsGapDetailTasks.print_gap_heading_details(context)
    end
  end
end

module SelfTextsGapSummaryTasks
module_function

  def gap_context
    goods_nomenclatures_table = Sequel[:goods_nomenclatures]
    self_texts_table = Sequel[:goods_nomenclature_self_texts]
    base = gap_base_dataset(goods_nomenclatures_table, self_texts_table)
    needing_work = base.where(Sequel.expr(self_texts_table[:goods_nomenclature_sid] => nil) | Sequel.expr(self_texts_table[:stale] => true))
    chapter_stats = gap_chapter_stats(base, goods_nomenclatures_table, self_texts_table)

    { goods_nomenclatures_table:, self_texts_table:, needing_work:, chapter_stats:, chapter_descs: gap_chapter_descriptions }
  end

  def gap_base_dataset(goods_nomenclatures_table, self_texts_table)
    base = GoodsNomenclature.actual
      .non_hidden
      .exclude(goods_nomenclatures_table[:goods_nomenclature_item_id] => Chapter.actual.select(:goods_nomenclature_item_id))
      .left_join(:goods_nomenclature_self_texts, { self_texts_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })

    return base unless ENV['CHAPTER']

    base.where(Sequel.like(goods_nomenclatures_table[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
  end

  def gap_chapter_stats(base, goods_nomenclatures_table, self_texts_table)
    base
      .select_group(Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch))
      .select_append { count(Sequel.lit('*')).as(total) }
      .select_append { count(Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[{ self_texts_table[:stale] => true }, 1]], nil)).as(stale) }
      .order(:ch)
      .all
  end

  def gap_chapter_descriptions
    Chapter.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |chapter| [chapter.goods_nomenclature_item_id.first(2), chapter.description&.truncate(50)] }
  end

  def print_gap_chapter_summary(context)
    puts 'Self-Text Gaps and Stale Records by Chapter'
    puts '=' * 100
    printf "%-4s %-50s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Work', 'Cov %'
    puts '-' * 100
    context[:chapter_stats].each { |row| print_gap_chapter_row(row, context[:chapter_descs]) }
    print_gap_chapter_total(context[:chapter_stats])
  end

  def print_gap_chapter_row(row, chapter_descs)
    total = row[:total]
    work = row[:missing] + row[:stale]
    coverage = total.positive? ? ((total - row[:missing]) * 100.0 / total).round(1) : 0
    printf "%-4s %-50s %6d %6d %6d %6d %6.1f%%\n",
           row[:ch], chapter_descs[row[:ch]] || '?', total, row[:missing], row[:stale], work, coverage
  end

  def print_gap_chapter_total(chapter_stats)
    totals = gap_chapter_totals(chapter_stats)
    puts '-' * 100
    printf "%-55s %6d %6d %6d %6d %6.1f%%\n",
           'TOTAL', totals[:total], totals[:missing], totals[:stale], totals[:work], totals[:coverage]
    puts
  end

  def gap_chapter_totals(chapter_stats)
    total = chapter_stats.sum { |row| row[:total] }
    missing = chapter_stats.sum { |row| row[:missing] }
    stale = chapter_stats.sum { |row| row[:stale] }
    work = missing + stale
    coverage = total.positive? ? ((total - missing) * 100.0 / total).round(1) : 0

    { total:, missing:, stale:, work:, coverage: }
  end
end

module SelfTextsGapDetailTasks
module_function

  def print_gap_heading_details(context)
    if gap_chapters(context[:chapter_stats]).any?
      print_gap_headings(context)
    else
      puts 'No gaps found - full coverage, nothing stale!'
    end
  end

  def gap_chapters(chapter_stats)
    chapter_stats.select { |row| row[:missing].positive? || row[:stale].positive? }.map { |row| row[:ch] }
  end

  def print_gap_headings(context)
    heading_stats = gap_heading_stats(context)
    heading_descs = gap_heading_descriptions
    puts 'Self-Texts Needing Work by Heading'
    puts '=' * 90
    printf "%-6s %-50s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Work'
    puts '-' * 90
    print_gap_heading_rows(heading_stats, context[:chapter_descs], heading_descs)
    puts
    print_gap_work_rows(context)
  end

  def gap_heading_stats(context)
    goods_nomenclatures_table = context[:goods_nomenclatures_table]
    self_texts_table = context[:self_texts_table]
    context[:needing_work].select_group(
      Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch),
      Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 4).as(:hd),
    )
      .select_append { count(Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[{ self_texts_table[:stale] => true }, 1]], nil)).as(stale) }
      .order(:ch, :hd)
      .all
  end

  def gap_heading_descriptions
    Heading.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |heading| [heading.goods_nomenclature_item_id.first(4), heading.description&.truncate(50)] }
  end

  def print_gap_heading_rows(heading_stats, chapter_descs, heading_descs)
    current_chapter = nil
    heading_stats.each do |row|
      current_chapter = print_gap_heading_chapter(row[:ch], current_chapter, chapter_descs)
      work = row[:missing] + row[:stale]
      printf "  %-4s %-48s %6d %6d %6d\n", row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], work
    end
  end

  def print_gap_heading_chapter(chapter, current_chapter, chapter_descs)
    return current_chapter if chapter == current_chapter

    puts "-- Chapter #{chapter}: #{chapter_descs[chapter] || '?'} --"
    chapter
  end

  def print_gap_work_rows(context)
    work_rows = gap_work_rows(context)
    puts 'All Goods Nomenclatures Needing Work (ordered by item_id, producline_suffix)'
    puts '=' * 110
    printf "%-12s %-4s %-7s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
    puts '-' * 110
    print_gap_work_row_details(work_rows) if work_rows.any?
    puts '-' * 110
    puts "Total needing work: #{work_rows.size}"
  end

  def gap_work_rows(context)
    goods_nomenclatures_table = context[:goods_nomenclatures_table]
    self_texts_table = context[:self_texts_table]
    context[:needing_work].select(
      goods_nomenclatures_table[:goods_nomenclature_sid],
      goods_nomenclatures_table[:goods_nomenclature_item_id],
      goods_nomenclatures_table[:producline_suffix],
      Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 'missing']], 'stale').as(:reason),
    )
      .order(goods_nomenclatures_table[:goods_nomenclature_item_id], goods_nomenclatures_table[:producline_suffix])
      .all
  end

  def print_gap_work_row_details(work_rows)
    descriptions = gap_work_descriptions(work_rows)
    work_rows.each do |row|
      printf "%-12s %-4s %-7s %-80s\n",
             row[:goods_nomenclature_item_id], row[:producline_suffix], row[:reason], descriptions[row[:goods_nomenclature_sid]] || '?'
    end
  end

  def gap_work_descriptions(work_rows)
    work_sids = work_rows.map { |row| row[:goods_nomenclature_sid] }
    GoodsNomenclature.actual
      .where(goods_nomenclature_sid: work_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }
  end
end

module SelfTextsValidationTasks
module_function

  def validate
    threshold = ENV.fetch('THRESHOLD', '0.7').to_f
    flag_below = ENV.key?('THRESHOLD')
    validate_similarity(threshold, flag_below)
    validate_coherence(threshold)
  end

  def validate_similarity(threshold, flag_below)
    puts '=' * 80
    puts 'PART A: EU Reference Comparison (similarity_score)'
    puts '=' * 80
    pairs = GoodsNomenclatureSelfText.exclude(similarity_score: nil).order(:similarity_score).all

    return puts 'No similarity scores found. Run self_texts:score first.' if pairs.empty?

    similarities = pairs.map(&:similarity_score)
    print_score_summary('pairs', similarities, threshold)
    print_low_similarity_pairs(pairs)
    puts "Below threshold: #{similarities.count { |score| score < threshold }} records" if flag_below
  end

  def validate_coherence(threshold)
    puts
    puts '=' * 80
    puts 'PART B: Coherence Check (no EU reference)'
    puts '=' * 80
    gap_nodes = GoodsNomenclatureSelfText.exclude(coherence_score: nil).order(:coherence_score).all

    return puts 'No coherence scores found. Run self_texts:score first.' if gap_nodes.empty?

    scores = gap_nodes.map(&:coherence_score)
    print_score_summary('gap nodes', scores, threshold, score_name: 'coherence')
    print_low_coherence_nodes(gap_nodes)
  end

  def print_score_summary(label, scores, threshold, score_name: 'similarity')
    puts "Total #{label}: #{scores.size}"
    puts "Mean #{score_name}: #{(scores.sum / scores.size).round(4)}"
    puts "Median: #{percentile(scores, 50).round(4)}"
    puts "P5: #{percentile(scores, 5).round(4)}"
    puts "P95: #{percentile(scores, 95).round(4)}"
    puts "Below #{threshold}: #{scores.count { |score| score < threshold }}"
    puts
  end

  def print_low_similarity_pairs(pairs)
    puts 'Bottom 20 lowest-similarity pairs:'
    puts '-' * 80
    pairs.first(20).each_with_index do |row, index|
      puts "#{index + 1}. [#{row.goods_nomenclature_item_id}] similarity=#{row.similarity_score.round(4)}"
      puts "   Generated: #{row.self_text&.truncate(120)}"
      puts "   EU:        #{row.eu_self_text&.truncate(120)}"
      puts
    end
  end

  def print_low_coherence_nodes(gap_nodes)
    puts 'Bottom 20 lowest-coherence gap nodes:'
    puts '-' * 80
    gap_nodes.first(20).each_with_index do |row, index|
      puts "#{index + 1}. [#{row.goods_nomenclature_item_id}] coherence=#{row.coherence_score.round(4)}"
      puts "   Generated: #{row.self_text&.truncate(120)}"
      puts
    end
  end

  def percentile(values, pct)
    return 0.0 if values.empty?

    sorted = values.sort
    percentile_index = (pct / 100.0) * (sorted.size - 1)
    floor = percentile_index.floor
    ceiling = percentile_index.ceil

    return sorted[floor] if floor == ceiling

    sorted[floor] + (percentile_index - floor) * (sorted[ceiling] - sorted[floor])
  end
end

namespace :self_texts do
  desc('Show self-text coverage statistics')
  task(coverage: :environment) { SelfTextsCoverageTasks.coverage }
  desc('Regenerate all self-texts by marking them stale and re-enqueuing')
  task(regenerate: :environment) { SelfTextsGenerationTasks.regenerate }
  desc('Generate self-texts for all chapters (background) or a single chapter (inline with CHAPTER=XX)')
  task(generate: :environment) { SelfTextsGenerationTasks.generate }
  desc('Populate EU reference self-texts from CSV into existing generated rows')
  task(populate_eu_references: :environment) { SelfTextsEuReferenceTasks.populate_eu_references }
  desc('Generate embeddings for self-texts and EU references via OpenAI')
  task(generate_embeddings: :environment) { SelfTextsEmbeddingTasks.generate_embeddings }
  desc('Fix encoding artefacts (e.g. pure9e -> puree) in existing AI-generated self-texts')
  task(fix_encoding_artefacts: :environment) { SelfTextsCleanupTasks.fix_encoding_artefacts }
  desc('Score all self-texts (populate EU refs, generate embeddings, compute confidence)')
  task(score: :environment) { SelfTextsCleanupTasks.score }
  desc('Show busy and queued self-text generation workers with chapter details')
  task(status: :environment) { SelfTextsStatusTasks.status }
  desc('Show self-text gaps and stale records grouped by chapter and heading (CHAPTER=XX to filter)')
  task(gaps: :environment) { SelfTextsGapTasks.gaps }
  desc('Validate generated self-texts - report similarity and coherence scores')
  task(validate: :environment) { SelfTextsValidationTasks.validate }
end
