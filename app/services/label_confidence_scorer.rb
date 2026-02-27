class LabelConfidenceScorer
  def initialize(embedding_service: EmbeddingService.new)
    @embedding_service = embedding_service
  end

  def score(sids)
    return if sids.empty?

    labels = GoodsNomenclatureLabel.where(goods_nomenclature_sid: sids).all
    return if labels.empty?

    self_text_embeddings = load_self_text_embeddings(sids)
    return if self_text_embeddings.empty?

    scorable = labels.select { |l| self_text_embeddings.key?(l.goods_nomenclature_sid) }
    return if scorable.empty?

    LabelGenerator::Instrumentation.scoring_started(total_records: scorable.size)

    LabelGenerator::Instrumentation.scoring_completed do |payload|
      score_labels(scorable, self_text_embeddings)
      populate_scoring_payload(payload, sids)
    end
  rescue StandardError => e
    LabelGenerator::Instrumentation.scoring_failed(error: e)
    raise
  end

  private

  attr_reader :embedding_service

  def load_self_text_embeddings(sids)
    rows = db[<<~SQL].all
      SELECT goods_nomenclature_sid, embedding
      FROM goods_nomenclature_self_texts
      WHERE goods_nomenclature_sid IN (#{sids.join(',')})
        AND embedding IS NOT NULL
    SQL

    rows.to_h { |r| [r[:goods_nomenclature_sid], parse_vector(r[:embedding])] }
  end

  def score_labels(labels, self_text_embeddings)
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

    text_map.each_with_index do |entry, i|
      st_embedding = self_text_embeddings[entry[:sid]]
      similarity = cosine_similarity(embeddings[i], st_embedding)

      case entry[:field]
      when :description
        results[entry[:sid]][:description_score] = similarity
      when :synonyms
        results[entry[:sid]][:synonym_scores][entry[:index]] = similarity
      when :colloquial_terms
        results[entry[:sid]][:colloquial_term_scores][entry[:index]] = similarity
      end
    end

    persist_scores(results)
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

  def cosine_similarity(vec_a, vec_b)
    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0

    vec_a.zip(vec_b).each do |a, b|
      dot += a * b
      norm_a += a * a
      norm_b += b * b
    end

    denominator = Math.sqrt(norm_a) * Math.sqrt(norm_b)
    return 0.0 if denominator.zero?

    (dot / denominator).round(4)
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
    stats = db[<<~SQL].first
      SELECT
        COUNT(*) FILTER (WHERE description_score IS NOT NULL) AS scored,
        AVG(description_score) AS mean_description_score
      FROM goods_nomenclature_labels
      WHERE goods_nomenclature_sid IN (#{sids.join(',')})
    SQL

    payload[:scored] = stats[:scored]
    payload[:mean_description_score] = stats[:mean_description_score]&.to_f&.round(4)
  end

  def parse_vector(value)
    return value if value.is_a?(Array)

    value.to_s.delete('[]').split(',').map(&:to_f)
  end

  def db
    Sequel::Model.db
  end
end
