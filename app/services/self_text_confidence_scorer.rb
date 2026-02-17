class SelfTextConfidenceScorer
  def initialize(embedding_service: EmbeddingService.new)
    @embedding_service = embedding_service
  end

  # Score a set of self-text records by SID.
  # Populates EU references, generates embeddings, and computes confidence scores.
  def score(sids)
    return if sids.empty?

    records = GoodsNomenclatureSelfText.where(goods_nomenclature_sid: sids).all
    return if records.empty?

    populate_eu_references(records)
    generate_embeddings(records)
    compute_similarity_scores(sids)
    compute_coherence_scores(records.select do |r|
      r.reload
      r.eu_self_text.nil? && r.embedding
    end)
  end

  private

  attr_reader :embedding_service

  def populate_eu_references(records)
    records.each do |record|
      eu_text = SelfTextLookupService.lookup(record.goods_nomenclature_item_id)
      next if eu_text.blank?

      GoodsNomenclatureSelfText
        .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
        .where(Sequel.|({ eu_self_text: nil }, Sequel.~(eu_self_text: eu_text)))
        .update(eu_self_text: eu_text, eu_embedding: nil)
    end
  end

  def generate_embeddings(records)
    # Generated text embeddings
    needs_gen = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: records.map(&:goods_nomenclature_sid))
      .where(embedding: nil)
      .exclude(self_text: nil)
      .all

    embed_column(needs_gen, :self_text, :embedding) if needs_gen.any?

    # EU reference embeddings
    needs_eu = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: records.map(&:goods_nomenclature_sid))
      .where(eu_embedding: nil)
      .exclude(eu_self_text: nil)
      .all

    embed_column(needs_eu, :eu_self_text, :eu_embedding) if needs_eu.any?
  end

  def embed_column(records, text_column, embedding_column)
    records.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
      texts = batch.map(&text_column)
      embeddings = embedding_service.embed_batch(texts)

      batch.zip(embeddings).each do |record, embedding|
        GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
          .update(embedding_column => Sequel.lit("'[#{embedding.join(',')}]'::vector"))
      end
    end
  end

  def compute_similarity_scores(sids)
    Sequel::Model.db.run(<<~SQL)
      UPDATE goods_nomenclature_self_texts
      SET similarity_score = 1 - (embedding <=> eu_embedding)
      WHERE goods_nomenclature_sid IN (#{sids.join(',')})
        AND embedding IS NOT NULL
        AND eu_embedding IS NOT NULL
    SQL
  end

  def compute_coherence_scores(gap_records)
    return if gap_records.empty?

    gap_records.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
      ancestor_texts = batch.map { |record| ancestor_chain_text(record) }
      ancestor_embeddings = embedding_service.embed_batch(ancestor_texts)

      batch.zip(ancestor_embeddings).each do |record, ancestor_embedding|
        gen_embedding_str = Sequel::Model.db[<<~SQL, record.goods_nomenclature_sid].first[:embedding_arr]
          SELECT embedding::text AS embedding_arr
          FROM goods_nomenclature_self_texts
          WHERE goods_nomenclature_sid = ?
        SQL

        gen_vec = gen_embedding_str.tr('[]', '').split(',').map(&:to_f)
        score = cosine_similarity(gen_vec, ancestor_embedding)

        GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
          .update(coherence_score: score)
      end
    end
  end

  def ancestor_chain_text(record)
    context = record.input_context
    ancestors = context['ancestors'] || []
    descriptions = ancestors.map { |a| a['self_text'] || a['description'] }
    descriptions << context['description']
    descriptions.compact.join(' > ')
  end

  def cosine_similarity(vec_a, vec_b)
    dot = vec_a.zip(vec_b).sum { |a, b| a * b }
    mag_a = Math.sqrt(vec_a.sum { |a| a**2 })
    mag_b = Math.sqrt(vec_b.sum { |b| b**2 })

    return 0.0 if mag_a.zero? || mag_b.zero?

    dot / (mag_a * mag_b)
  end
end
