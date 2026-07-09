module SearchEmbeddingsRakeTasks
  module_function

  def generate
    sids = GoodsNomenclatureSelfText
      .exclude(self_text: nil)
      .order(:goods_nomenclature_sid)
      .select_map(:goods_nomenclature_sid)

    total = sids.size
    puts "Checking #{total} self-text records for stale embeddings..."

    regenerate_embeddings(sids, total)
  end

  def coverage
    SearchEmbeddingsCoverageRakeTasks.coverage
  end

  def gaps
    SearchEmbeddingsGapsRakeTasks.gaps
  end

  def regenerate_embeddings(sids, total)
    checked = 0
    embedded = 0

    sids.each_slice(batch_size) do |batch|
      embedded += GoodsNomenclatureSelfText.regenerate_search_embeddings(batch)

      checked += batch.size
      print_generate_progress(checked, total, embedded)
    end

    puts "Done. #{embedded}/#{total} records needed re-embedding."
  end

  def print_generate_progress(checked, total, embedded)
    return unless (checked % 500).zero? || checked >= total

    puts "  #{checked}/#{total} checked, #{embedded} embedded"
  end

  def batch_size
    ENV.fetch('BATCH_SIZE', 500).to_i
  end
end

module SearchEmbeddingsCoverageRakeTasks
  module_function

  def coverage
    TimeMachine.now do
      with_self_text_ds = GoodsNomenclatureSelfText.exclude(self_text: nil)
      total = with_self_text_ds.count
      has_embedding = with_self_text_ds.exclude(search_embedding: nil).count
      missing = total - has_embedding
      stale = stale_embedding_count(with_self_text_ds)

      print_coverage(total:, has_embedding:, missing:, stale:)
    end
  end

  def stale_embedding_count(with_self_text_ds)
    stale = 0
    sids_with_embedding = with_self_text_ds
      .exclude(search_embedding: nil)
      .order(:goods_nomenclature_sid)
      .select_map(:goods_nomenclature_sid)

    sids_with_embedding.each_slice(batch_size) do |sid_batch|
      stale += stale_embedding_count_for(sid_batch)
    end

    stale
  end

  def stale_embedding_count_for(sid_batch)
    records = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sid_batch)
      .exclude(self_text: nil)
      .all
    composite_texts = CompositeSearchTextBuilder.batch(records)
    records.count do |record|
      composite_texts[record.goods_nomenclature_sid] != record.search_text
    end
  end

  def print_coverage(total:, has_embedding:, missing:, stale:)
    needing_work = missing + stale
    coverage = total.positive? ? (has_embedding * 100.0 / total).round(2) : 0

    puts 'Search Embedding Coverage Statistics'
    puts '-' * 38
    puts "With self-text:        #{total}"
    puts "Has search_embedding:  #{has_embedding}"
    puts "Missing embedding:     #{missing}"
    puts "Stale (text drifted):  #{stale}"
    puts "Needing work:          #{needing_work}"
    puts "Coverage:              #{coverage}%"
  end

  def batch_size
    ENV.fetch('BATCH_SIZE', 500).to_i
  end
end

module SearchEmbeddingsGapsRakeTasks
  module_function

  def gaps
    TimeMachine.now do
      chapter_stats = chapter_embedding_stats
      chapter_descs = chapter_descriptions

      print_chapter_gaps(chapter_stats, chapter_descs)
    end
  end

  def chapter_embedding_stats
    goods_nomenclatures = Sequel[:goods_nomenclatures]
    self_texts = Sequel[:goods_nomenclature_self_texts]

    chapter_gap_base(goods_nomenclatures, self_texts)
      .select_group(Sequel.function(:substr, goods_nomenclatures[:goods_nomenclature_item_id], 1, 2).as(:ch))
      .select_append { count(Sequel.lit('*')).as(total) }
      .select_append { count(Sequel.case([[{ self_texts[:search_embedding] => nil }, 1]], nil)).as(missing) }
      .order(:ch)
      .all
  end

  def chapter_gap_base(goods_nomenclatures, self_texts)
    base = GoodsNomenclatureSelfText
      .exclude(self_texts[:self_text] => nil)
      .join(:goods_nomenclatures, { goods_nomenclatures[:goods_nomenclature_sid] => self_texts[:goods_nomenclature_sid] })
      .where(GoodsNomenclature.validity_dates_filter)

    return base unless ENV['CHAPTER']

    base.where(Sequel.like(goods_nomenclatures[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
  end

  def chapter_descriptions
    Chapter.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |chapter| [chapter.goods_nomenclature_item_id.first(2), chapter.description&.truncate(50)] }
  end

  def print_chapter_gaps(chapter_stats, chapter_descs)
    puts 'Search Embedding Gaps by Chapter'
    puts '=' * 100
    printf "%-4s %-50s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Cov %'
    puts '-' * 100

    chapter_stats.each do |row|
      print_chapter_gap(row, chapter_descs)
    end

    print_chapter_gap_totals(chapter_stats)
    puts
    puts 'Note: Stale embeddings (text drifted) not shown per-chapter. Use search_embeddings:coverage for that.'
  end

  def print_chapter_gap(row, chapter_descs)
    ch = row[:ch]
    total = row[:total]
    miss = row[:missing]
    cov = total.positive? ? ((total - miss) * 100.0 / total).round(1) : 0
    printf "%-4s %-50s %6d %6d %6.1f%%\n", ch, chapter_descs[ch] || '?', total, miss, cov
  end

  def print_chapter_gap_totals(chapter_stats)
    total_all = chapter_stats.sum { |row| row[:total] }
    miss_all = chapter_stats.sum { |row| row[:missing] }
    cov_all = total_all.positive? ? ((total_all - miss_all) * 100.0 / total_all).round(1) : 0
    puts '-' * 100
    printf "%-55s %6d %6d %6.1f%%\n", 'TOTAL', total_all, miss_all, cov_all
  end
end

desc 'Generate search_embedding and search_text for all self-text records (skips unchanged)'
task 'search_embeddings:generate' => :environment do
  SearchEmbeddingsRakeTasks.generate
end

desc 'Show search embedding coverage statistics (computes stale count via composite text comparison)'
task 'search_embeddings:coverage' => :environment do
  SearchEmbeddingsRakeTasks.coverage
end

desc 'Show search embedding gaps by chapter (CHAPTER=XX to filter)'
task 'search_embeddings:gaps' => :environment do
  SearchEmbeddingsRakeTasks.gaps
end
