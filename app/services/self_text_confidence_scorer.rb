class SelfTextConfidenceScorer
  def initialize(embedding_service: EmbeddingService.new)
    @embedding_service = embedding_service
  end

  # Score a set of self-text records by SID.
  # Populates EU references, generates embeddings, and computes confidence scores.
  def score(sids, chapter_code: nil)
    return if sids.empty?

    @chapter_code = chapter_code

    records = GoodsNomenclatureSelfText.where(goods_nomenclature_sid: sids).all
    return if records.empty?

    SelfTextGenerator::Instrumentation.scoring_started(
      chapter_code: @chapter_code,
      total_records: records.size,
    )

    SelfTextGenerator::Instrumentation.scoring_completed(chapter_code: @chapter_code) do |payload|
      populate_eu_references(records)
      generate_embeddings(records)
      compute_similarity_scores(sids)

      gap_records = GoodsNomenclatureSelfText
        .where(goods_nomenclature_sid: sids)
        .where(eu_self_text: nil)
        .exclude(embedding: nil)
        .all

      compute_coherence_scores(gap_records)
      populate_scoring_payload(payload, sids)
    end
  rescue StandardError => e
    SelfTextGenerator::Instrumentation.scoring_failed(chapter_code: @chapter_code, error: e)
    raise
  end

  private

  attr_reader :embedding_service

  def populate_eu_references(records)
    non_declarable = non_declarable_sids_for(records)

    pairs = records.filter_map do |record|
      next if non_declarable.include?(record.goods_nomenclature_sid)

      eu_text = SelfTextLookupService.lookup(record.goods_nomenclature_item_id)
      next if eu_text.blank?

      [record.goods_nomenclature_sid, eu_text]
    end

    return if pairs.empty?

    values = pairs.map { |sid, text|
      "(#{sid}, #{db.literal(text)})"
    }.join(', ')

    db.run(<<~SQL)
      UPDATE goods_nomenclature_self_texts t
      SET eu_self_text = v.eu_text,
          eu_embedding = NULL
      FROM (VALUES #{values}) AS v(goods_nomenclature_sid, eu_text)
      WHERE t.goods_nomenclature_sid = v.goods_nomenclature_sid
        AND (t.eu_self_text IS NULL OR t.eu_self_text != v.eu_text)
    SQL
  end

  def generate_embeddings(records)
    sids = records.map(&:goods_nomenclature_sid)

    needs_gen = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .where(embedding: nil)
      .exclude(self_text: nil)
      .all

    embed_column(needs_gen, :self_text, :embedding) if needs_gen.any?

    needs_eu = GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .where(eu_embedding: nil)
      .exclude(eu_self_text: nil)
      .all

    embed_column(needs_eu, :eu_self_text, :eu_embedding) if needs_eu.any?
  end

  def embed_column(records, text_column, embedding_column)
    records.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
      texts = batch.map(&text_column)

      embeddings = SelfTextGenerator::Instrumentation.embedding_api_call(
        batch_size: texts.size,
        model: EmbeddingService::MODEL,
        chapter_code: @chapter_code,
      ) { embedding_service.embed_batch(texts) }

      values = batch.zip(embeddings).map { |record, embedding|
        "(#{record.goods_nomenclature_sid}, '[#{embedding.join(',')}]'::vector)"
      }.join(', ')

      db.run(<<~SQL)
        UPDATE goods_nomenclature_self_texts t
        SET #{embedding_column} = v.embedding
        FROM (VALUES #{values}) AS v(goods_nomenclature_sid, embedding)
        WHERE t.goods_nomenclature_sid = v.goods_nomenclature_sid
      SQL
    end
  end

  def compute_similarity_scores(sids)
    db.run(<<~SQL)
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

      ancestor_embeddings = SelfTextGenerator::Instrumentation.embedding_api_call(
        batch_size: ancestor_texts.size,
        model: EmbeddingService::MODEL,
        chapter_code: @chapter_code,
      ) { embedding_service.embed_batch(ancestor_texts) }

      values = batch.zip(ancestor_embeddings).map { |record, embedding|
        "(#{record.goods_nomenclature_sid}, '[#{embedding.join(',')}]'::vector)"
      }.join(', ')

      db.run(<<~SQL)
        UPDATE goods_nomenclature_self_texts t
        SET coherence_score = 1 - (t.embedding <=> v.ancestor_embedding)
        FROM (VALUES #{values}) AS v(goods_nomenclature_sid, ancestor_embedding)
        WHERE t.goods_nomenclature_sid = v.goods_nomenclature_sid
      SQL
    end
  end

  def populate_scoring_payload(payload, sids)
    stats = db[<<~SQL].first
      SELECT
        COUNT(*) FILTER (WHERE eu_self_text IS NOT NULL) AS eu_matched,
        COUNT(*) FILTER (WHERE embedding IS NOT NULL) AS embeddings_generated,
        AVG(similarity_score) AS mean_similarity,
        AVG(coherence_score) AS mean_coherence
      FROM goods_nomenclature_self_texts
      WHERE goods_nomenclature_sid IN (#{sids.join(',')})
    SQL

    payload[:eu_matched] = stats[:eu_matched]
    payload[:embeddings_generated] = stats[:embeddings_generated]
    payload[:mean_similarity] = stats[:mean_similarity]&.to_f&.round(4)
    payload[:mean_coherence] = stats[:mean_coherence]&.to_f&.round(4)
  end

  def ancestor_chain_text(record)
    context = record.input_context
    ancestors = context['ancestors'] || []
    ancestor_sids = ancestors.filter_map { |a| a['sid'] }

    current_texts = if ancestor_sids.any?
                      GoodsNomenclatureSelfText
                        .where(goods_nomenclature_sid: ancestor_sids)
                        .select_hash(:goods_nomenclature_sid, :self_text)
                    else
                      {}
                    end

    descriptions = ancestors.map do |a|
      current_texts[a['sid']] || a['self_text'] || a['description']
    end

    descriptions.compact.join(' >> ')
  end

  def non_declarable_sids_for(records)
    sids = records.map(&:goods_nomenclature_sid)
    return Set.new if sids.empty?

    declarable_sids = TimeMachine.now do
      GoodsNomenclature
        .actual
        .declarable
        .where(Sequel[:goods_nomenclatures][:goods_nomenclature_sid] => sids)
        .unordered
        .select_map(Sequel[:goods_nomenclatures][:goods_nomenclature_sid])
    end
    (sids - declarable_sids).to_set
  end

  def db
    Sequel::Model.db
  end
end
