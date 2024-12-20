class SearchService
  class ExactSearch < BaseSearch
    def search!
      @results = case query_string
                 # A CAS number, in the format e.g., "178535-93-8", e.g. /\d+-\d+-\d/
                 when /\A(cas\s*)?(\d+-\d+-\d)\z/i
                   matchdata = /\A(cas\s*)?(\d+-\d+-\d)\z/i.match(query_string)
                   q = matchdata ? matchdata[2] : query_string.gsub(/\Acas\s+/i, '')
                   find_search_suggestion(q)
                 else
                   find_search_suggestion(query_string) ||
                     find_search_suggestion(query_string.ljust(10, '0')) ||
                     find_historic_goods_nomenclature(query_string)
                 end

      self
    end

    def present?
      !query_string.in?(HiddenGoodsNomenclature.codes) && results.present?
    end

    def serializable_hash
      {
        type: 'exact_match',
        entry: {
          endpoint: results.class.name.parameterize(separator: '_').pluralize,
          id: results.to_param,
        },
      }
    end

    private

    def find_search_suggestion(query)
      filter = { value: singular_and_plural(query) }
      if resource_id.present? && resource_id != 'undefined'
        filter[:id] = resource_id
      end

      suggestion = SearchSuggestion.find(filter)

      suggestion&.goods_nomenclature&.sti_cast
    end

    def find_historic_goods_nomenclature(query)
      return nil unless query.match(/\A\d+\z/)

      short_code = query.first(10)
      producline_suffix = query.length > 10 ? query.last(2) : nil
      goods_nomenclature_item_id = short_code.ljust(10, '0')
      filter = { goods_nomenclature_item_id: }
      filter[:producline_suffix] = producline_suffix if producline_suffix.present?

      goods_nomenclature = GoodsNomenclature
        .non_hidden
        .where(filter)
        .limit(1)
        .first

      return unless goods_nomenclature

      check_for_children_on =
        if goods_nomenclature.validity_end_date && goods_nomenclature.validity_end_date < @date
          goods_nomenclature.validity_end_date
        elsif goods_nomenclature.validity_start_date && goods_nomenclature.validity_start_date > @date
          goods_nomenclature.validity_start_date
        else
          @date
        end

      # Check whether Subheading or Commodity at the appropriate point in time
      TimeMachine.at(check_for_children_on) { goods_nomenclature.sti_cast }
    end

    # Example:
    # 'cookie' => ['cookie', 'cookies']
    # 'leaves' => ['leaf', 'leaves']
    def singular_and_plural(query)
      [
        query,
        query.singularize,
        query.pluralize,
      ].uniq
    end
  end
end
