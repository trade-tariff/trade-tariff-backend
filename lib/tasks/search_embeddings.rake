namespace :search_embeddings do
  desc 'Generate search_embedding and search_text for all self-text records (skips unchanged)'
  task generate: :environment do
    sids = GoodsNomenclatureSelfText
      .exclude(self_text: nil)
      .order(:goods_nomenclature_sid)
      .select_map(:goods_nomenclature_sid)

    total = sids.size
    puts "Checking #{total} self-text records for stale embeddings..."

    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
    checked = 0
    embedded = 0

    sids.each_slice(batch_size) do |batch|
      embedded += GoodsNomenclatureSelfText.regenerate_search_embeddings(batch)

      checked += batch.size
      if (checked % 500).zero? || checked >= total
        puts "  #{checked}/#{total} checked, #{embedded} embedded"
      end
    end

    puts "Done. #{embedded}/#{total} records needed re-embedding."
  end

  desc 'Show search embedding coverage statistics (computes stale count via composite text comparison)'
  task coverage: :environment do
    TimeMachine.now do
      with_self_text_ds = GoodsNomenclatureSelfText.exclude(self_text: nil)
      total = with_self_text_ds.count
      has_embedding = with_self_text_ds.exclude(search_embedding: nil).count
      missing = total - has_embedding

      # Compute stale count by comparing stored search_text against freshly-built composite text
      batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
      stale = 0

      sids_with_embedding = with_self_text_ds
        .exclude(search_embedding: nil)
        .order(:goods_nomenclature_sid)
        .select_map(:goods_nomenclature_sid)

      sids_with_embedding.each_slice(batch_size) do |sid_batch|
        records = GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: sid_batch)
          .exclude(self_text: nil)
          .all
        composite_texts = CompositeSearchTextBuilder.batch(records)
        records.each do |record|
          stale += 1 if composite_texts[record.goods_nomenclature_sid] != record.search_text
        end
      end

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
  end

  desc 'Show search embedding gaps by chapter (CHAPTER=XX to filter)'
  task gaps: :environment do
    TimeMachine.now do
      gn = Sequel[:goods_nomenclatures]
      st = Sequel[:goods_nomenclature_self_texts]

      # Self-text records joined to GN for chapter grouping
      base = GoodsNomenclatureSelfText
        .exclude(st[:self_text] => nil)
        .join(:goods_nomenclatures, { gn[:goods_nomenclature_sid] => st[:goods_nomenclature_sid] })
        .where(GoodsNomenclature.validity_dates_filter)

      if ENV['CHAPTER']
        base = base.where(Sequel.like(gn[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
      end

      # --- Chapter summary (missing embeddings only - cheap DB query) ---
      chapter_stats = base
        .select_group(Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2).as(:ch))
        .select_append { count(Sequel.lit('*')).as(total) }
        .select_append { count(Sequel.case([[{ st[:search_embedding] => nil }, 1]], nil)).as(missing) }
        .order(:ch)
        .all

      chapter_descs = Chapter.actual
        .eager(:goods_nomenclature_descriptions)
        .all
        .to_h { |c| [c.goods_nomenclature_item_id.first(2), c.description&.truncate(50)] }

      puts 'Search Embedding Gaps by Chapter'
      puts '=' * 100
      printf "%-4s %-50s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Cov %'
      puts '-' * 100

      chapter_stats.each do |row|
        ch = row[:ch]
        total = row[:total]
        miss = row[:missing]
        cov = total.positive? ? ((total - miss) * 100.0 / total).round(1) : 0
        printf "%-4s %-50s %6d %6d %6.1f%%\n", ch, chapter_descs[ch] || '?', total, miss, cov
      end

      total_all = chapter_stats.sum { |r| r[:total] }
      miss_all = chapter_stats.sum { |r| r[:missing] }
      cov_all = total_all.positive? ? ((total_all - miss_all) * 100.0 / total_all).round(1) : 0
      puts '-' * 100
      printf "%-55s %6d %6d %6.1f%%\n", 'TOTAL', total_all, miss_all, cov_all
      puts
      puts 'Note: Stale embeddings (text drifted) not shown per-chapter. Use search_embeddings:coverage for that.'
    end
  end
end
