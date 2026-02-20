class GoodsNomenclatureSelfText < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key # PK is a natural key (FK to goods_nomenclatures), not auto-increment

  GENERATION_TYPES = %w[mechanical ai].freeze

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   primary_key: :goods_nomenclature_sid

  dataset_module do
    def stale
      where(stale: true)
    end

    def needs_review
      where(needs_review: true)
    end

    def vector_search(vector_literal, limit:)
      distance_expr = Sequel.lit("goods_nomenclature_self_texts.search_embedding <=> #{vector_literal}")

      exclude(search_embedding: nil)
        .association_join(:goods_nomenclature)
        .where(goods_nomenclature__producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)
        .where { GoodsNomenclature.validity_dates_filter(:goods_nomenclature) }
        .exclude(goods_nomenclature__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes)
        .select(Sequel[:goods_nomenclature][:goods_nomenclature_sid])
        .select_append(Sequel.as(Sequel.lit("1 - (#{distance_expr})"), :score))
        .order(distance_expr)
        .limit(limit)
    end
  end

  def validate
    super
    validates_includes GENERATION_TYPES, :generation_type
  end

  def self.lookup(sid)
    self[sid]&.self_text
  end

  def self.regenerate_search_embeddings(sids)
    records = where(goods_nomenclature_sid: sids).exclude(self_text: nil).where(search_embedding: nil).all
    return if records.empty?

    embedding_service = EmbeddingService.new
    db = Sequel::Model.db

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
    end
  end

  def mark_stale!
    update(stale: true)
  end

  def context_stale?(current_hash)
    context_hash != current_hash
  end
end
