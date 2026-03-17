namespace :self_texts do
  desc 'Show self-text coverage statistics'
  task coverage: :environment do
    TimeMachine.now do
      total_gn = GoodsNomenclature.actual.non_hidden.count - Chapter.actual.count
      total_self_texts = GoodsNomenclatureSelfText.count
      missing = total_gn - total_self_texts
      stale = GoodsNomenclatureSelfText.where(stale: true).count
      needing_work = missing + stale
      coverage = total_gn.positive? ? (total_self_texts * 100.0 / total_gn).round(2) : 0

      by_type = GoodsNomenclatureSelfText
        .group_and_count(:generation_type)
        .order(:generation_type)
        .all

      puts 'Self-Text Coverage Statistics'
      puts '-' * 30
      puts "Total GN (excl. chapters): #{total_gn}"
      puts "With self-text:            #{total_self_texts}"
      puts "Missing:                   #{missing}"
      puts "Coverage:                  #{coverage}%"
      puts "Stale:                     #{stale}"
      puts "Needing work:              #{needing_work}"
      puts
      puts 'By generation type:'
      by_type.each { |row| puts "  #{row[:generation_type]}: #{row[:count]}" }
    end
  end

  desc 'Regenerate all self-texts by marking them stale and re-enqueuing'
  task regenerate: :environment do
    count = GoodsNomenclatureSelfText.where(stale: false, manually_edited: false).update(stale: true)
    puts "Marked #{count} self-texts as stale."

    GenerateSelfTextWorker.perform_async
    puts 'Enqueued regeneration. Check Sidekiq for progress.'
  end

  desc 'Generate self-texts for all chapters (background) or a single chapter (inline with CHAPTER=XX)'
  task generate: :environment do
    if ENV['CHAPTER']
      chapter = TimeMachine.now { Chapter.actual.by_code(ENV['CHAPTER']).take }
      raise "Chapter #{ENV['CHAPTER']} not found" unless chapter

      puts "Generating self-texts for chapter #{ENV['CHAPTER']}..."
      ai = GenerateSelfText::OtherSelfTextBuilder.call(chapter)
      non_other_ai = GenerateSelfText::NonOtherSelfTextBuilder.call(chapter)
      puts "Other AI: #{ai.inspect}"
      puts "Non-Other AI: #{non_other_ai.inspect}"
    else
      puts 'Enqueuing self-text generation for all chapters...'
      GenerateSelfTextWorker.perform_async
      puts 'Done. Check Sidekiq for progress.'
    end
  end

  desc 'Populate EU reference self-texts from CSV into existing generated rows'
  task populate_eu_references: :environment do
    require 'csv'

    csv_path = Rails.root.join('data/CN2026_SelfText_EN_DE_FR.csv')

    unless File.exist?(csv_path)
      puts "CSV not found at #{csv_path}"
      exit 1
    end

    stats = { updated: 0, skipped_no_match: 0, skipped_blank: 0 }

    CSV.foreach(csv_path, headers: true) do |row|
      code = row['CN_CODE']
      eu_text = row['SelfText_EN']&.strip

      next stats[:skipped_blank] += 1 if code.blank? || eu_text.blank?

      normalized = code.gsub(/\s/, '').ljust(10, '0')

      count = GoodsNomenclatureSelfText
        .where(goods_nomenclature_item_id: normalized)
        .where(Sequel.|(
                 { eu_self_text: nil },
                 Sequel.~(eu_self_text: eu_text),
               ))
        .update(eu_self_text: eu_text, eu_embedding: nil)

      if count.positive?
        stats[:updated] += count
      else
        existing = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: normalized).count
        stats[:skipped_no_match] += 1 if existing.zero?
      end
    end

    puts "EU references populated: #{stats[:updated]} updated, #{stats[:skipped_no_match]} no matching generated text, #{stats[:skipped_blank]} blank"
  end

  desc 'Generate embeddings for self-texts and EU references via OpenAI'
  task generate_embeddings: :environment do
    service = EmbeddingService.new

    # Pass 1: generated self-texts missing embeddings
    generate_texts = GoodsNomenclatureSelfText
      .where(embedding: nil)
      .exclude(self_text: nil)
      .select(:goods_nomenclature_sid, :self_text)
      .all

    puts "Pass 1: #{generate_texts.size} generated self-texts need embeddings..."

    generate_texts.each_slice(EmbeddingService::BATCH_SIZE).with_index do |batch, i|
      texts = batch.map(&:self_text)
      embeddings = service.embed_batch(texts)

      batch.zip(embeddings).each do |record, embedding|
        GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
          .update(embedding: Sequel.lit("'[#{embedding.join(',')}]'::vector"))
      end

      processed = [(i + 1) * EmbeddingService::BATCH_SIZE, generate_texts.size].min
      puts "  Generated: #{processed}/#{generate_texts.size} embedded"
    end

    # Pass 2: EU references missing embeddings
    eu_texts = GoodsNomenclatureSelfText
      .where(eu_embedding: nil)
      .exclude(eu_self_text: nil)
      .select(:goods_nomenclature_sid, :eu_self_text)
      .all

    puts "Pass 2: #{eu_texts.size} EU references need embeddings..."

    eu_texts.each_slice(EmbeddingService::BATCH_SIZE).with_index do |batch, i|
      texts = batch.map(&:eu_self_text)
      embeddings = service.embed_batch(texts)

      batch.zip(embeddings).each do |record, embedding|
        GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
          .update(eu_embedding: Sequel.lit("'[#{embedding.join(',')}]'::vector"))
      end

      processed = [(i + 1) * EmbeddingService::BATCH_SIZE, eu_texts.size].min
      puts "  EU: #{processed}/#{eu_texts.size} embedded"
    end

    puts 'Embedding generation complete.'
  end

  desc 'Fix encoding artefacts (e.g. pure9e -> puree) in existing AI-generated self-texts'
  task fix_encoding_artefacts: :environment do
    sanitiser = GenerateSelfText::EncodingArtefactSanitiser
    fixed = 0

    GoodsNomenclatureSelfText.where(generation_type: %w[ai ai_non_other]).each do |record|
      sanitised = sanitiser.call(record.self_text)
      next if sanitised == record.self_text

      record.update(
        self_text: sanitised,
        embedding: nil,
        search_embedding: nil,
        search_embedding_stale: true,
      )
      fixed += 1
      puts "Fixed [#{record.goods_nomenclature_item_id}] sid=#{record.goods_nomenclature_sid}: #{record.self_text.truncate(80)}"
    end

    puts "Done. Fixed #{fixed} records."
  end

  desc 'Score all self-texts (populate EU refs, generate embeddings, compute confidence)'
  task score: :environment do
    sids = GoodsNomenclatureSelfText.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} self-texts..."

    SelfTextConfidenceScorer.new.score(sids)

    puts 'Scoring complete.'
  end

  desc 'Show busy and queued self-text generation workers with chapter details'
  task status: :environment do
    require 'json'

    TimeMachine.now do
      puts 'BUSY:'
      Sidekiq::Workers.new.each do |_pid, _tid, work|
        payload = JSON.parse(work.payload)
        next unless payload['class'].include?('SelfText')

        sid = payload['args']&.first
        ch = Chapter.where(goods_nomenclature_sid: sid).first
        label = ch ? "#{ch.goods_nomenclature_item_id.first(2)} - #{ch.description}" : "sid=#{sid}"
        puts "  #{label} (running since #{Time.zone.at(work.run_at)})"
      end

      puts
      queued = Sidekiq::Queue.all.flat_map do |q|
        q.select { |j| j.klass.include?('SelfText') }
      end

      puts "QUEUED (#{queued.size}):"
      queued.each do |job|
        sid = job.args&.first
        ch = Chapter.where(goods_nomenclature_sid: sid).first
        label = ch ? "#{ch.goods_nomenclature_item_id.first(2)} - #{ch.description}" : "sid=#{sid}"
        puts "  #{label} (enqueued #{Time.zone.at(job.enqueued_at)}) [#{job.queue}]"
      end
    end
  end

  desc 'Show self-text gaps and stale records grouped by chapter and heading (CHAPTER=XX to filter)'
  task gaps: :environment do
    TimeMachine.now do
      gn = Sequel[:goods_nomenclatures]
      st = Sequel[:goods_nomenclature_self_texts]

      # All actual non-chapter GN items left-joined to self_texts
      base = GoodsNomenclature.actual
        .non_hidden
        .exclude(gn[:goods_nomenclature_item_id] => Chapter.actual.select(:goods_nomenclature_item_id))
        .left_join(:goods_nomenclature_self_texts, { st[:goods_nomenclature_sid] => gn[:goods_nomenclature_sid] })

      if ENV['CHAPTER']
        base = base.where(Sequel.like(gn[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
      end

      needing_work_ds = base.where(Sequel.expr(st[:goods_nomenclature_sid] => nil) | Sequel.expr(st[:stale] => true))

      # --- Chapter summary ---
      chapter_stats = base
        .select_group(Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2).as(:ch))
        .select_append { count(Sequel.lit('*')).as(total) }
        .select_append { count(Sequel.case([[{ st[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
        .select_append { count(Sequel.case([[{ st[:stale] => true }, 1]], nil)).as(stale) }
        .order(:ch)
        .all

      # Load chapter descriptions for display
      chapter_descs = Chapter.actual
        .eager(:goods_nomenclature_descriptions)
        .all
        .to_h { |c| [c.goods_nomenclature_item_id.first(2), c.description&.truncate(50)] }

      puts 'Self-Text Gaps and Stale Records by Chapter'
      puts '=' * 100
      printf "%-4s %-50s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Work', 'Cov %'
      puts '-' * 100

      chapter_stats.each do |row|
        ch = row[:ch]
        total = row[:total]
        miss = row[:missing]
        stale = row[:stale]
        work = miss + stale
        cov = total.positive? ? ((total - miss) * 100.0 / total).round(1) : 0
        printf "%-4s %-50s %6d %6d %6d %6d %6.1f%%\n", ch, chapter_descs[ch] || '?', total, miss, stale, work, cov
      end

      total_all = chapter_stats.sum { |r| r[:total] }
      miss_all = chapter_stats.sum { |r| r[:missing] }
      stale_all = chapter_stats.sum { |r| r[:stale] }
      work_all = miss_all + stale_all
      cov_all = total_all.positive? ? ((total_all - miss_all) * 100.0 / total_all).round(1) : 0
      puts '-' * 100
      printf "%-55s %6d %6d %6d %6d %6.1f%%\n", 'TOTAL', total_all, miss_all, stale_all, work_all, cov_all
      puts

      # --- Heading detail (only chapters with work needed) ---
      gap_chapters = chapter_stats.select { |r| r[:missing].positive? || r[:stale].positive? }.map { |r| r[:ch] }

      if gap_chapters.any?
        heading_stats = needing_work_ds
          .select_group(
            Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2).as(:ch),
            Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 4).as(:hd),
          )
          .select_append { count(Sequel.case([[{ st[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
          .select_append { count(Sequel.case([[{ st[:stale] => true }, 1]], nil)).as(stale) }
          .order(:ch, :hd)
          .all

        heading_descs = Heading.actual
          .eager(:goods_nomenclature_descriptions)
          .all
          .to_h { |h| [h.goods_nomenclature_item_id.first(4), h.description&.truncate(50)] }

        puts 'Self-Texts Needing Work by Heading'
        puts '=' * 90
        printf "%-6s %-50s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Work'
        puts '-' * 90

        current_ch = nil
        heading_stats.each do |row|
          if row[:ch] != current_ch
            current_ch = row[:ch]
            puts "-- Chapter #{current_ch}: #{chapter_descs[current_ch] || '?'} --"
          end
          work = row[:missing] + row[:stale]
          printf "  %-4s %-48s %6d %6d %6d\n", row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], work
        end
        puts

        # --- Full list of GN items needing work ---
        puts 'All Goods Nomenclatures Needing Work (ordered by item_id, producline_suffix)'
        puts '=' * 110
        printf "%-12s %-4s %-7s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
        puts '-' * 110

        work_rows = needing_work_ds
          .select(
            gn[:goods_nomenclature_sid],
            gn[:goods_nomenclature_item_id],
            gn[:producline_suffix],
            Sequel.case([[{ st[:goods_nomenclature_sid] => nil }, 'missing']], 'stale').as(:reason),
          )
          .order(gn[:goods_nomenclature_item_id], gn[:producline_suffix])
          .all

        if work_rows.any?
          work_sids = work_rows.map { |r| r[:goods_nomenclature_sid] }
          descriptions = GoodsNomenclature.actual
            .where(goods_nomenclature_sid: work_sids)
            .eager(:goods_nomenclature_descriptions)
            .all
            .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }

          work_rows.each do |row|
            printf "%-12s %-4s %-7s %-80s\n",
                   row[:goods_nomenclature_item_id],
                   row[:producline_suffix],
                   row[:reason],
                   descriptions[row[:goods_nomenclature_sid]] || '?'
          end
        end

        puts '-' * 110
        puts "Total needing work: #{work_rows.size}"
      else
        puts 'No gaps found - full coverage, nothing stale!'
      end
    end
  end

  desc 'Validate generated self-texts - report similarity and coherence scores'
  task validate: :environment do
    threshold = ENV.fetch('THRESHOLD', '0.7').to_f
    flag_below = ENV.key?('THRESHOLD')

    # Part A: EU comparison (similarity_score)
    puts '=' * 80
    puts 'PART A: EU Reference Comparison (similarity_score)'
    puts '=' * 80

    pairs = GoodsNomenclatureSelfText
      .exclude(similarity_score: nil)
      .order(:similarity_score)
      .all

    if pairs.any?
      similarities = pairs.map(&:similarity_score)

      puts "Total pairs: #{pairs.size}"
      puts "Mean similarity: #{(similarities.sum / similarities.size).round(4)}"
      puts "Median: #{self_text_percentile(similarities, 50).round(4)}"
      puts "P5: #{self_text_percentile(similarities, 5).round(4)}"
      puts "P95: #{self_text_percentile(similarities, 95).round(4)}"
      puts "Below #{threshold}: #{similarities.count { |s| s < threshold }}"
      puts

      puts 'Bottom 20 lowest-similarity pairs:'
      puts '-' * 80

      pairs.first(20).each_with_index do |row, i|
        puts "#{i + 1}. [#{row.goods_nomenclature_item_id}] similarity=#{row.similarity_score.round(4)}"
        puts "   Generated: #{row.self_text&.truncate(120)}"
        puts "   EU:        #{row.eu_self_text&.truncate(120)}"
        puts
      end

      if flag_below
        puts "Below threshold: #{similarities.count { |s| s < threshold }} records"
      end
    else
      puts 'No similarity scores found. Run self_texts:score first.'
    end

    # Part B: Coherence check (coherence_score)
    puts
    puts '=' * 80
    puts 'PART B: Coherence Check (no EU reference)'
    puts '=' * 80

    gap_nodes = GoodsNomenclatureSelfText
      .exclude(coherence_score: nil)
      .order(:coherence_score)
      .all

    if gap_nodes.any?
      scores = gap_nodes.map(&:coherence_score)

      puts "Total gap nodes: #{gap_nodes.size}"
      puts "Mean coherence: #{(scores.sum / scores.size).round(4)}"
      puts "Median: #{self_text_percentile(scores, 50).round(4)}"
      puts "P5: #{self_text_percentile(scores, 5).round(4)}"
      puts "P95: #{self_text_percentile(scores, 95).round(4)}"
      puts "Below #{threshold}: #{scores.count { |s| s < threshold }}"
      puts

      puts 'Bottom 20 lowest-coherence gap nodes:'
      puts '-' * 80

      gap_nodes.first(20).each_with_index do |row, i|
        puts "#{i + 1}. [#{row.goods_nomenclature_item_id}] coherence=#{row.coherence_score.round(4)}"
        puts "   Generated: #{row.self_text&.truncate(120)}"
        puts
      end
    else
      puts 'No coherence scores found. Run self_texts:score first.'
    end
  end
end

def self_text_percentile(values, pct)
  return 0.0 if values.empty?

  sorted = values.sort
  k = (pct / 100.0) * (sorted.size - 1)
  f = k.floor
  c = k.ceil

  return sorted[f] if f == c

  sorted[f] + (k - f) * (sorted[c] - sorted[f])
end
