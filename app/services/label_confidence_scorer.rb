class LabelConfidenceScorer
  def initialize(embedding_service: EmbeddingService.new)
    @embedding_service = embedding_service
  end

  def score(sids)
    return if sids.empty?

    labels = GoodsNomenclatureLabel.where(goods_nomenclature_sid: sids).all
    return if labels.empty?

    scorable_sids = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .exclude(embedding: nil)
      .select_map(:goods_nomenclature_sid)
      .to_set

    return if scorable_sids.empty?

    scorable = labels.select { |l| scorable_sids.include?(l.goods_nomenclature_sid) }
    return if scorable.empty?

    LabelGenerator::Instrumentation.scoring_started(total_records: scorable.size)

    LabelGenerator::Instrumentation.scoring_completed do |payload|
      score_labels(scorable)
      populate_scoring_payload(payload, sids)
    end
  rescue StandardError => e
    LabelGenerator::Instrumentation.scoring_failed(error: e)
    raise
  end

  private

  attr_reader :embedding_service

  def score_labels(labels)
    all_texts = []
    text_map = []

    labels.each do |label|
      if label.description.present?
        text_map << { sid: label.goods_nomenclature_sid, field: :description, index: nil }
        all_texts << label.description
      end

      Array(label.synonyms).each_with_index do |term, i|
        next if term.blank?

        text_map << { sid: label.goods_nomenclature_sid, field: :synonyms, index: i }
        all_texts << term
      end

      Array(label.colloquial_terms).each_with_index do |term, i|
        next if term.blank?

        text_map << { sid: label.goods_nomenclature_sid, field: :colloquial_terms, index: i }
        all_texts << term
      end
    end

    return if all_texts.empty?

    embeddings = embed_all(all_texts)

    results = Hash.new { |h, k| h[k] = { description_score: nil, synonym_scores: [], colloquial_term_scores: [] } }

    labels.each do |label|
      sid = label.goods_nomenclature_sid
      results[sid][:synonym_scores] = Array.new(Array(label.synonyms).size)
      results[sid][:colloquial_term_scores] = Array.new(Array(label.colloquial_terms).size)
    end

    rows = compute_similarities(text_map, embeddings)

    rows.each do |row|
      sid = row[:goods_nomenclature_sid]
      score = row[:score].to_f

      case row[:field]
      when 'description'
        results[sid][:description_score] = score
      when 'synonyms'
        results[sid][:synonym_scores][row[:idx]] = score
      when 'colloquial_terms'
        results[sid][:colloquial_term_scores][row[:idx]] = score
      end
    end

    persist_scores(results)
  end

  # Uses the generation embedding (not search_embedding) because search_embedding
  # incorporates label text, which would make the comparison circular.
  def compute_similarities(text_map, embeddings)
    values = text_map.each_with_index.map { |entry, i|
      vector = "'[#{embeddings[i].join(',')}]'::vector"
      "(#{entry[:sid]}, #{db.literal(entry[:field].to_s)}, #{entry[:index] || 0}, #{vector})"
    }.join(', ')

    db[<<~SQL].all
      SELECT v.goods_nomenclature_sid, v.field, v.idx,
             ROUND((1 - (v.term_embedding <=> st.embedding))::numeric, 4) AS score
      FROM (VALUES #{values}) AS v(goods_nomenclature_sid, field, idx, term_embedding)
      JOIN goods_nomenclature_self_texts st
        ON st.goods_nomenclature_sid = v.goods_nomenclature_sid
    SQL
  end

  def embed_all(texts)
    all_embeddings = []

    texts.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
      batch_embeddings = LabelGenerator::Instrumentation.embedding_api_call(
        batch_size: batch.size,
        model: EmbeddingService::MODEL,
      ) { embedding_service.embed_batch(batch) }

      all_embeddings.concat(batch_embeddings)
    end

    all_embeddings
  end

  def persist_scores(results)
    results.each do |sid, scores|
      GoodsNomenclatureLabel
        .where(goods_nomenclature_sid: sid)
        .update(
          description_score: scores[:description_score],
          synonym_scores: Sequel.pg_array(scores[:synonym_scores], :float),
          colloquial_term_scores: Sequel.pg_array(scores[:colloquial_term_scores], :float),
        )
    end
  end

  def populate_scoring_payload(payload, sids)
    dataset = GoodsNomenclatureLabel.where(goods_nomenclature_sid: sids)

    payload[:scored] = dataset.exclude(description_score: nil).count
    payload[:mean_description_score] = dataset.exclude(description_score: nil)
      .avg(:description_score)&.to_f&.round(4)
  end

  def db
    Sequel::Model.db
  end
end
