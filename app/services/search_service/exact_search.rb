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
                   find_search_suggestion(query_string)
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
      if resource_id.present?
        filter[:id] = resource_id
      end

      suggestion = SearchSuggestion.find(filter)

      suggestion&.custom_sti_goods_nomenclature
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
