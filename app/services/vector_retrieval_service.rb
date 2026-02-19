class VectorRetrievalService
  def self.call(query:, as_of:, limit: 80)
    new(query:, as_of:, limit:).call
  end

  def initialize(query:, as_of:, limit: 80)
    @query = query
    @as_of = as_of
    @limit = limit
  end

  def call
    query_embedding = embedding_service.embed(@query)
    vector_literal = "'[#{query_embedding.join(',')}]'::vector"

    ranked_rows = fetch_ranked_sids(vector_literal)
    return [] if ranked_rows.empty?

    scores_by_sid = ranked_rows.each_with_object({}) { |r, h| h[r[:goods_nomenclature_sid]] = r[:score]&.to_f }
    ordered_sids = ranked_rows.map { |r| r[:goods_nomenclature_sid] }

    gn_by_sid = load_goods_nomenclatures(ordered_sids)

    ordered_sids.filter_map do |sid|
      gn = gn_by_sid[sid]
      next unless gn

      build_result(gn, scores_by_sid[sid])
    end
  end

  private

  def fetch_ranked_sids(vector_literal)
    ef_search = AdminConfiguration.integer_value('vector_ef_search')

    db.transaction do
      db.run("SET LOCAL hnsw.ef_search = #{ef_search.to_i}")

      TimeMachine.at(@as_of) do
        GoodsNomenclatureSelfText
          .vector_search(vector_literal, limit: @limit)
          .all
      end
    end
  end

  def load_goods_nomenclatures(sids)
    TimeMachine.at(@as_of) do
      GoodsNomenclature
        .actual
        .with_leaf_column
        .where(goods_nomenclatures__goods_nomenclature_sid: sids)
        .eager(:goods_nomenclature_descriptions, :heading)
        .all
        .index_by(&:goods_nomenclature_sid)
    end
  end

  def build_result(goods_nomenclature, score)
    self_text = SelfTextLookupService.lookup(goods_nomenclature.goods_nomenclature_item_id)
    full_desc = self_text.presence ||
      DescriptionHtmlFormatter.call(goods_nomenclature.raw_classification_description)

    OpenStruct.new(
      id: goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      producline_suffix: goods_nomenclature.producline_suffix,
      goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
      description: goods_nomenclature.description_html,
      formatted_description: goods_nomenclature.description_html,
      full_description: full_desc,
      heading_description: goods_nomenclature.heading&.description_html,
      declarable: goods_nomenclature.respond_to?(:declarable?) ? goods_nomenclature.declarable? : false,
      score: score,
      confidence: nil,
    )
  end

  def embedding_service
    @embedding_service ||= EmbeddingService.new
  end

  def db
    Sequel::Model.db
  end
end
