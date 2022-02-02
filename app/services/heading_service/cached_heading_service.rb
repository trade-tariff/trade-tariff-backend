module HeadingService
  class CachedHeadingService
    attr_reader :heading, :as_of, :result

    def initialize(heading, as_of)
      @heading = heading
      @as_of = as_of
    end

    def serializable_hash
      @result = fetch_result || serialize_result
      if result.present? && as_of.present?
        filter_chapter
        filter_footnotes
        filter_commodities
        filter_commodity_relations
        build_commodities_tree
      end
      result
    end

    private

    def serialize_result
      Hashie::TariffMash.new(::Cache::HeadingSerializer.new(heading).as_json)
    end

    def fetch_result
      search_client = ::TradeTariffBackend.cache_client
      index = ::Cache::HeadingIndex.new(TradeTariffBackend.search_namespace).name
      result = search_client.search index: index, body: { query: { match: { _id: heading.goods_nomenclature_sid } } }
      result&.hits&.hits&.first&._source
    end

    def filter_chapter
      result.delete(:chapter) if result.chapter.present? && !has_valid_dates(result.chapter)
      result.chapter_id = result.chapter&.goods_nomenclature_sid
    end

    def filter_footnotes
      result.footnotes.keep_if do |footnote|
        has_valid_dates(footnote)
      end
      result.footnote_ids = result.footnotes.map do |footnote|
        footnote.footnote_id
      end
    end

    def filter_commodities
      result.commodities.keep_if do |commodity|
        has_valid_dates(commodity)
      end
      result.commodity_ids = result.commodities.map do |commodity|
        commodity.goods_nomenclature_sid
      end
    end

    def filter_commodity_relations
      result.commodities.each do |commodity|
        commodity.overview_measures.keep_if do |measure|
          has_valid_dates(measure, :effective_start_date, :effective_end_date)
        end

        commodity.overview_measures = OverviewMeasurePresenter.new(commodity.overview_measures, commodity).validate!

        commodity.overview_measure_ids = commodity.overview_measures.map do |measure|
          measure.measure_sid
        end

        commodity.goods_nomenclature_indents.keep_if do |ident|
          has_valid_dates(ident)
        end

        indent = commodity.goods_nomenclature_indents.sort_by do |ident|
          Date.parse ident.validity_start_date
        end.last

        commodity.number_indents = indent.number_indents
        commodity.producline_suffix = indent.productline_suffix

        commodity.goods_nomenclature_descriptions.keep_if do |description|
          has_valid_dates(description)
        end

        description = commodity.goods_nomenclature_descriptions.sort_by do |description|
          Date.parse description.validity_start_date
        end.last

        commodity.description = description.description
        commodity.formatted_description = description.formatted_description
        commodity.description_plain = description.description_plain
      end
    end

    # TODO: Use the TimeMachine plugin to filter the correct associated entities
    def has_valid_dates(hash, start_key = :validity_start_date, end_key = :validity_end_date)
      hash[start_key].to_date <= as_of &&
        (hash[end_key].nil? || hash[end_key].to_date >= as_of)
    end

    def build_commodities_tree
      AnnotatedCommodityService.new(result).call
    end
  end
end
