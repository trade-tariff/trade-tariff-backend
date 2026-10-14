module Search
  class ResultAncestors
    def self.attach(response, as_of:)
      new(as_of:).attach(response)
    end

    def initialize(as_of:)
      @as_of = as_of
    end

    def attach(response)
      item_ids = Array(response[:data]).filter_map { |item| item.dig(:attributes, :goods_nomenclature_item_id).to_s.presence }
      return response if item_ids.empty?

      # Display context only. Shared heading and chapter codes are loaded once
      # after ranking, so this does not add a retrieval leg or change scores.
      TimeMachine.at(@as_of) do
        records = load_records(item_ids)
        apply(response, index_by_code(records, Heading), index_by_code(records, Chapter))
      end
    end

  private

    def load_records(item_ids)
      codes = item_ids.flat_map { |item_id| [heading_code_for(item_id), chapter_code_for(item_id)] }.compact.uniq
      return [] if codes.empty?

      GoodsNomenclature
        .actual
        .non_hidden
        .where(
          goods_nomenclature_item_id: codes,
          producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX,
        )
        .eager(:goods_nomenclature_descriptions)
        .all
    end

    def index_by_code(records, klass)
      records.each_with_object({}) do |record, indexed|
        indexed[record.goods_nomenclature_item_id] = record if record.is_a?(klass)
      end
    end

    def apply(response, headings_by_code, chapters_by_code)
      data = Array(response[:data])
      primary_keys = data.each_with_object({}) do |item, keys|
        keys[resource_key(item[:type], item[:id])] = true
      end
      included = {}

      data.each do |item|
        item_id = item.dig(:attributes, :goods_nomenclature_item_id).to_s
        heading = headings_by_code[heading_code_for(item_id)]
        chapter = chapters_by_code[chapter_code_for(item_id)]
        relationships = {}

        if heading && heading.goods_nomenclature_item_id != item_id
          relationships[:heading] = linkage(:heading, heading)
          add_included(included, primary_keys, heading) { included_heading(heading, chapter) }
        end

        if chapter && chapter.goods_nomenclature_item_id != item_id
          relationships[:chapter] = linkage(:chapter, chapter)
          add_included(included, primary_keys, chapter) { included_resource(chapter) }
        end

        item[:relationships] = relationships if relationships.any?
      end

      response[:included] = included.values if included.any?
      response
    end

    # A valid compound document does not repeat a primary resource in the
    # included array. Linkage for an ancestor that is itself a primary
    # resource stays on the primary item; consumers resolve it from data.
    def add_included(included, primary_keys, record)
      return if primary_keys[resource_key(resource_type(record), record.goods_nomenclature_sid.to_s)]

      included[record.goods_nomenclature_sid] ||= yield
    end

    def resource_key(type, id)
      [type.to_s, id.to_s]
    end

    def included_heading(heading, chapter)
      resource = included_resource(heading)
      resource[:relationships] = { chapter: linkage(:chapter, chapter) } if chapter
      resource
    end

    def included_resource(record)
      description = display_description(record)
      {
        id: record.goods_nomenclature_sid.to_s,
        type: resource_type(record),
        attributes: {
          goods_nomenclature_item_id: record.goods_nomenclature_item_id,
          producline_suffix: record.producline_suffix,
          goods_nomenclature_class: record.goods_nomenclature_class,
          description:,
          formatted_description: description,
        },
      }
    end

    def resource_type(record)
      record.goods_nomenclature_class.underscore.to_sym
    end

    def linkage(type, record)
      { data: { type:, id: record.goods_nomenclature_sid.to_s } }
    end

    def display_description(record)
      record.formatted_description.presence || record.description.to_s
    end

    def heading_code_for(item_id)
      code_for(item_id, 4, GoodsNomenclature::HEADING_SUFFIX)
    end

    def chapter_code_for(item_id)
      code_for(item_id, 2, GoodsNomenclature::CHAPTER_SUFFIX)
    end

    def code_for(item_id, length, suffix)
      id = item_id.to_s
      return if id.length < length || id.end_with?(GoodsNomenclature::CHAPTER_SUFFIX)

      "#{id.first(length)}#{suffix}"
    end
  end
end
