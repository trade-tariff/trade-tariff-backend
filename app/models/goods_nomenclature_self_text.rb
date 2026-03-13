class GoodsNomenclatureSelfText < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key # PK is a natural key (FK to goods_nomenclatures), not auto-increment

  GENERATION_TYPES = %w[mechanical ai ai_non_other].freeze

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   primary_key: :goods_nomenclature_sid

  dataset_module do
    include AdminListingDataset

    def stale
      where(stale: true)
    end

    def needs_review
      where(needs_review: true)
    end

    def admin_listing
      st = Sequel[:goods_nomenclature_self_texts]

      join(:goods_nomenclatures, { Sequel[:gn][:goods_nomenclature_sid] => st[:goods_nomenclature_sid] }, table_alias: :gn)
        .select_all(:goods_nomenclature_self_texts)
        .select_append(
          nomenclature_type_expression.as(:nomenclature_type),
          score_expression.as(:score),
        )
        .where(st[:generation_type] => %w[ai ai_non_other])
    end

    def search(query)
      return self if query.blank?

      q = query.strip
      st = Sequel[:goods_nomenclature_self_texts]

      if q.match?(/\A\d{2,10}\z/)
        where(Sequel.like(st[:goods_nomenclature_item_id], "#{q}%"))
      elsif q.length >= 2
        term = "%#{q}%"
        where(
          Sequel.ilike(st[:self_text], term) |
          Sequel.ilike(Sequel.cast(st[:input_context], String), term),
        )
      else
        self
      end
    end

    def for_status(status)
      st = Sequel[:goods_nomenclature_self_texts]

      case status
      when 'needs_review'
        where(st[:needs_review] => true)
      when 'stale'
        where(st[:stale] => true)
      when 'manually_edited'
        where(st[:manually_edited] => true)
      else
        self
      end
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

    private

    def score_expression
      st = Sequel[:goods_nomenclature_self_texts]
      similarity = st[:similarity_score]
      coherence = st[:coherence_score]
      similarity_present = ~Sequel.expr(similarity => nil)
      coherence_present = ~Sequel.expr(coherence => nil)

      Sequel.case(
        [
          [similarity_present & coherence_present, (similarity + coherence) / 2.0],
          [similarity_present, similarity],
          [coherence_present, coherence],
        ],
        nil,
      )
    end
  end

  def validate
    super
    validates_includes GENERATION_TYPES, :generation_type
  end

  class << self
    def lookup(sid)
      self[sid]&.self_text
    end

    def regenerate_search_embeddings(sids)
      candidates = with_self_text(sids)
      return 0 if candidates.empty?

      composite_texts = TimeMachine.now { CompositeSearchTextBuilder.batch(candidates) }
      stale_records = needing_embedding(candidates, composite_texts)
      return 0 if stale_records.empty?

      embed_in_batches(stale_records, composite_texts)
      stale_records.size
    end

    private

    def with_self_text(sids)
      where(goods_nomenclature_sid: sids)
        .exclude(self_text: nil)
        .all
    end

    def needing_embedding(candidates, composite_texts)
      candidates.select do |r|
        r.search_embedding.nil? || composite_texts[r.goods_nomenclature_sid] != r.search_text
      end
    end

    def embed_in_batches(records, composite_texts)
      embedding_service = EmbeddingService.new

      records.each_slice(EmbeddingService::BATCH_SIZE) do |batch|
        texts = batch.map { |r| composite_texts[r.goods_nomenclature_sid] }
        embeddings = embedding_service.embed_batch(texts)
        bulk_update_embeddings(batch, composite_texts, embeddings)
      end
    end

    def bulk_update_embeddings(batch, composite_texts, embeddings)
      db = Sequel::Model.db

      values = batch.zip(embeddings).map { |record, embedding|
        sid = record.goods_nomenclature_sid
        text = composite_texts[sid]
        vector = "'[#{embedding.join(',')}]'::vector"

        "(#{sid}, #{db.literal(text)}, #{vector})"
      }.join(', ')

      db.run(<<~SQL)
        UPDATE goods_nomenclature_self_texts t
        SET search_text = v.search_text,
            search_embedding = v.search_embedding,
            search_embedding_stale = false
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
