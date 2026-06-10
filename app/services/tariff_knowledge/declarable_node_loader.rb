module TariffKnowledge
  class DeclarableNodeLoader
    BATCH_SIZE = 500
    # Proxy/special declarables can describe their real CN chapter scope in the
    # hierarchy descriptions rather than in the item id. Capture the phrases we
    # currently see in those descriptions and store normalized chapter codes in
    # metadata so later graph loading does not need to parse hierarchy prose.
    CHAPTER_SCOPE_CODE_PATTERNS = [
      /\bClassified in Chapter\s+(\d{1,2})\b/i,
      /\bGoods from CN chapter\s+(\d{1,2})\b/i,
    ].freeze
    CHAPTER_SCOPE_RANGE_PATTERNS = [
      /\bGoods from CN chapters\s+(\d{1,2})\s+to\s+(\d{1,2})\b/i,
    ].freeze

    def self.call
      new.call
    end

    def call
      TimeMachine.now do
        GoodsNomenclature.actual
                         .with_leaf_column
                         .declarable
                         .eager(:goods_nomenclature_descriptions, ancestors: :goods_nomenclature_descriptions)
                         .paged_each(rows_per_fetch: BATCH_SIZE)
                         .each_slice(BATCH_SIZE) do |goods_nomenclatures|
          upsert_goods_nomenclature_nodes(goods_nomenclatures.map(&:sti_cast))
        end
      end
    end

  private

    def upsert_goods_nomenclature_nodes(goods_nomenclatures)
      rows = goods_nomenclatures.map { |goods_nomenclature| node_row(goods_nomenclature) }
      return if rows.empty?

      Node.dataset
          .insert_conflict(target: :key, update: update_values)
          .multi_insert(rows)
    end

    def node_row(goods_nomenclature)
      now = Time.zone.now

      {
        node_type: Node::GOODS_NOMENCLATURE,
        key: "goods_nomenclature:#{goods_nomenclature.goods_nomenclature_sid}",
        title: goods_nomenclature.goods_nomenclature_item_id,
        content: nil,
        metadata: Sequel.pg_jsonb(scope_metadata(goods_nomenclature)),
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        producline_suffix: goods_nomenclature.producline_suffix,
        goods_nomenclature_type: goods_nomenclature.goods_nomenclature_class,
        validity_start_date: goods_nomenclature.validity_start_date,
        validity_end_date: goods_nomenclature.validity_end_date,
        created_at: now,
        updated_at: now,
      }
    end

    def scope_metadata(goods_nomenclature)
      chapter_scope_codes = chapter_scope_codes(goods_nomenclature)
      chapter_scope_codes.any? ? { 'chapter_scope_codes' => chapter_scope_codes } : {}
    end

    def chapter_scope_codes(goods_nomenclature)
      descriptions = (goods_nomenclature.ancestors + [goods_nomenclature]).map do |item|
        item.description_plain.presence || item.description.presence
      end
      content = descriptions.compact.join(' ')
      codes = CHAPTER_SCOPE_CODE_PATTERNS.flat_map { |pattern| content.scan(pattern).flatten }
      codes += CHAPTER_SCOPE_RANGE_PATTERNS.flat_map do |pattern|
        content.scan(pattern).flat_map { |from_chapter, to_chapter| (from_chapter.to_i..to_chapter.to_i).to_a }
      end
      codes.map { |code| sprintf('%02d', code.to_i) }.uniq
    end

    def update_values
      {
        title: Sequel[:excluded][:title],
        content: Sequel[:excluded][:content],
        metadata: Sequel[:excluded][:metadata],
        goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
        goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
        producline_suffix: Sequel[:excluded][:producline_suffix],
        goods_nomenclature_type: Sequel[:excluded][:goods_nomenclature_type],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        updated_at: Sequel[:excluded][:updated_at],
      }
    end
  end
end
