namespace :search_embeddings do
  desc 'Generate search_embedding and search_text for all self-text records'
  task generate: :environment do
    embedding_service = EmbeddingService.new
    db = Sequel::Model.db

    records = GoodsNomenclatureSelfText
      .exclude(self_text: nil)
      .order(:goods_nomenclature_sid)
      .all

    total = records.size
    processed = 0

    puts "Generating search embeddings for #{total} self-text records..."

    records.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
      composite_texts = TimeMachine.now { CompositeSearchTextBuilder.batch(batch) }

      texts_to_embed = batch.map { |r| composite_texts[r.goods_nomenclature_sid] }
      embeddings = embedding_service.embed_batch(texts_to_embed)

      values = batch.zip(embeddings).map { |record, embedding|
        sid = record.goods_nomenclature_sid
        text = composite_texts[sid]
        vector = "'[#{embedding.join(',')}]'::vector"

        "(#{sid}, #{db.literal(text)}, #{vector})"
      }.join(', ')

      db.run(<<~SQL)
        UPDATE goods_nomenclature_self_texts t
        SET search_text = v.search_text,
            search_embedding = v.search_embedding
        FROM (VALUES #{values}) AS v(goods_nomenclature_sid, search_text, search_embedding)
        WHERE t.goods_nomenclature_sid = v.goods_nomenclature_sid
      SQL

      processed += batch.size

      if (processed % 500).zero? || processed >= total
        puts "  #{processed}/#{total} records processed"
      end
    end

    puts 'Done.'
  end
end
