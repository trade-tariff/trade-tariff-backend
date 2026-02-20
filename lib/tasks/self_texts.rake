namespace :self_texts do
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
      ai = GenerateSelfText::AiBuilder.call(chapter)
      mechanical = GenerateSelfText::MechanicalBuilder.call(chapter)
      puts "AI: #{ai.inspect}"
      puts "Mechanical: #{mechanical.inspect}"
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

  desc 'Score all self-texts (populate EU refs, generate embeddings, compute confidence)'
  task score: :environment do
    sids = GoodsNomenclatureSelfText.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} self-texts..."

    SelfTextConfidenceScorer.new.score(sids)

    puts 'Scoring complete.'
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
