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

    db.transaction do
      db.run('SET LOCAL hnsw.ef_search = 100')

      results = db.fetch(
        search_sql(vector_literal),
        as_of: @as_of,
        limit: @limit,
      ).all

      results.map { |row| build_result(row) }
    end
  end

  private

  def search_sql(vector_literal)
    # vector_literal is safe - it contains only numeric values from the embedding API
    <<~SQL
      SELECT gn.goods_nomenclature_sid,
             gn.goods_nomenclature_item_id,
             gn.producline_suffix,
             st.self_text AS full_description,
             1 - (st.search_embedding <=> #{vector_literal}) AS score
      FROM goods_nomenclature_self_texts st
      JOIN goods_nomenclatures gn
        ON gn.goods_nomenclature_sid = st.goods_nomenclature_sid
      WHERE st.search_embedding IS NOT NULL
        AND gn.producline_suffix = '80'
        AND gn.goods_nomenclature_item_id NOT IN (
          SELECT goods_nomenclature_item_id FROM hidden_goods_nomenclatures
        )
        AND (gn.validity_start_date IS NULL OR gn.validity_start_date <= :as_of)
        AND (gn.validity_end_date IS NULL OR gn.validity_end_date >= :as_of)
      ORDER BY st.search_embedding <=> #{vector_literal}
      LIMIT :limit
    SQL
  end

  def build_result(row)
    item_id = row[:goods_nomenclature_item_id]

    OpenStruct.new(
      id: row[:goods_nomenclature_sid],
      goods_nomenclature_item_id: item_id,
      goods_nomenclature_sid: row[:goods_nomenclature_sid],
      producline_suffix: row[:producline_suffix],
      goods_nomenclature_class: classify(item_id),
      description: row[:full_description],
      formatted_description: row[:full_description],
      full_description: row[:full_description],
      heading_description: nil,
      declarable: row[:producline_suffix] == '80',
      score: row[:score]&.to_f,
      confidence: nil,
    )
  end

  def classify(item_id)
    case item_id
    when /\A\d{2}00000000\z/ then 'Chapter'
    when /\A\d{4}000000\z/ then 'Heading'
    when /\A\d{10}\z/ then 'Commodity'
    else 'Subheading'
    end
  end

  def embedding_service
    @embedding_service ||= EmbeddingService.new
  end

  def db
    Sequel::Model.db
  end
end
