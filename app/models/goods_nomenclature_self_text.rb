class GoodsNomenclatureSelfText < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key # PK is a natural key (FK to goods_nomenclatures), not auto-increment

  GENERATION_TYPES = %w[mechanical ai ai_non_other].freeze

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   primary_key: :goods_nomenclature_sid

  dataset_module do
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

    def for_nomenclature_type(type)
      return self unless %w[commodity heading subheading].include?(type)

      where(Sequel.lit("(#{nomenclature_type_sql}) = ?", type))
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

    def for_score_category(category)
      score = Sequel.lit("(#{score_sql})")

      case category
      when 'bad'
        where(score < 0.3)
      when 'okay'
        where(score >= 0.3).where(score < 0.5)
      when 'good'
        where(score >= 0.5).where(score < 0.85)
      when 'amazing'
        where(score >= 0.85)
      when 'no_score'
        where(Sequel.lit("(#{score_sql}) IS NULL"))
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
      Sequel.lit(score_sql)
    end

    def nomenclature_type_expression
      Sequel.lit(nomenclature_type_sql)
    end

    def score_sql
      <<~SQL.squish
        CASE
          WHEN "goods_nomenclature_self_texts"."similarity_score" IS NOT NULL
           AND "goods_nomenclature_self_texts"."coherence_score" IS NOT NULL
          THEN ("goods_nomenclature_self_texts"."similarity_score" + "goods_nomenclature_self_texts"."coherence_score") / 2.0
          WHEN "goods_nomenclature_self_texts"."similarity_score" IS NOT NULL
          THEN "goods_nomenclature_self_texts"."similarity_score"
          WHEN "goods_nomenclature_self_texts"."coherence_score" IS NOT NULL
          THEN "goods_nomenclature_self_texts"."coherence_score"
        END
      SQL
    end

    def nomenclature_type_sql
      <<~SQL.squish
        CASE
          WHEN "gn"."goods_nomenclature_item_id" LIKE '__00000000' THEN 'chapter'
          WHEN "gn"."goods_nomenclature_item_id" LIKE '____000000' THEN 'heading'
          WHEN "gn"."producline_suffix" != '80' OR EXISTS (
            SELECT 1
            FROM goods_nomenclature_tree_nodes parent
            JOIN goods_nomenclature_tree_nodes child
              ON child.depth = parent.depth + 1
              AND child.position > parent.position
              AND child.validity_start_date <= CURRENT_DATE
              AND (child.validity_end_date >= CURRENT_DATE OR child.validity_end_date IS NULL)
              AND child.position < COALESCE(
                (SELECT MIN(siblings.position)
                 FROM goods_nomenclature_tree_nodes siblings
                 WHERE siblings.depth = parent.depth
                   AND siblings.position > parent.position
                   AND siblings.validity_start_date <= CURRENT_DATE
                   AND (siblings.validity_end_date >= CURRENT_DATE OR siblings.validity_end_date IS NULL)
                ), 1000000000000)
            WHERE parent.goods_nomenclature_sid = "gn"."goods_nomenclature_sid"
              AND parent.validity_start_date <= CURRENT_DATE
              AND (parent.validity_end_date >= CURRENT_DATE OR parent.validity_end_date IS NULL)
          ) THEN 'subheading'
          ELSE 'commodity'
        END
      SQL
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
    records = where(goods_nomenclature_sid: sids)
      .exclude(self_text: nil)
      .where(Sequel.expr(search_embedding_stale: true) | Sequel.expr(search_embedding: nil))
      .all
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
