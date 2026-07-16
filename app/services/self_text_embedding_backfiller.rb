class SelfTextEmbeddingBackfiller
  def self.call
    new.call
  end

  def call
    service = EmbeddingService.new
    generated = embedding_records(:embedding, :self_text, :self_text)
    $stdout.puts "Pass 1: #{generated.size} generated self-texts need embeddings..."
    generate_embedding_batches(
      service,
      generated,
      :embedding,
      :self_text,
      'Generated',
      event_kind: 'self_text_embedding_backfill',
    )

    eu_references = embedding_records(:eu_embedding, :eu_self_text, :eu_self_text)
    $stdout.puts "Pass 2: #{eu_references.size} EU references need embeddings..."
    generate_embedding_batches(
      service,
      eu_references,
      :eu_embedding,
      :eu_self_text,
      'EU',
      event_kind: 'eu_self_text_embedding_backfill',
    )
    $stdout.puts 'Embedding generation complete.'
  end

private

  def embedding_records(embedding_column, text_column, select_text_column)
    GoodsNomenclatureSelfText
      .where(embedding_column => nil)
      .exclude(text_column => nil)
      .select(:goods_nomenclature_sid, select_text_column)
      .all
  end

  def generate_embedding_batches(service, records, embedding_column, text_column, label, event_kind:)
    records.each_slice(EmbeddingService::BATCH_SIZE).with_index do |batch, index|
      texts = batch.map { |record| record.public_send(text_column) }
      embeddings = AiUsage::Instrumentation.embedding_api_call(
        event_kind:,
        batch_size: texts.size,
        model: EmbeddingService::MODEL,
      ) { service.embed_batch(texts, event_kind:) }
      update_embeddings(batch, embeddings, embedding_column)
      processed = [(index + 1) * EmbeddingService::BATCH_SIZE, records.size].min
      $stdout.puts "  #{label}: #{processed}/#{records.size} embedded"
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
