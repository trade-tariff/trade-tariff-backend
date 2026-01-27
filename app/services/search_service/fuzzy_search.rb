class SearchService
  class FuzzySearch < BaseSearch
    def search!
      @results ||= begin
        queries = build_queries
        responses = execute_msearch(queries)
        format_results(queries, responses)
      end

      self
    rescue OpenSearch::Transport::Transport::Error
      # rescue from malformed queries, return empty resultset in that case
      @results = BLANK_RESULT
      self
    end

    def serializable_hash
      {
        type: 'fuzzy_match',
      }.merge(results)
    end

    private

    def query_options
      {}
    end

    def build_queries
      @build_queries ||= [
        # Direct goods nomenclature queries
        Search::Fuzzy::GoodsNomenclatureQuery.new(query_string, date, Search::ChapterIndex.new),
        Search::Fuzzy::GoodsNomenclatureQuery.new(query_string, date, Search::HeadingIndex.new),
        Search::Fuzzy::GoodsNomenclatureQuery.new(query_string, date, Search::CommodityIndex.new),

        # Reference queries (all query SearchReferenceIndex, filtered by type)
        Search::Fuzzy::ReferenceQuery.new(query_string, date, Search::ChapterIndex.new),
        Search::Fuzzy::ReferenceQuery.new(query_string, date, Search::HeadingIndex.new),
        Search::Fuzzy::ReferenceQuery.new(query_string, date, Search::CommodityIndex.new),
      ]
    end

    def execute_msearch(queries)
      TradeTariffBackend.search_client.msearch(
        body: queries.map { |query| query.query(query_options_for(query)) },
      ).responses
    end

    def query_options_for(query)
      query_options.fetch(query.match_type, {})
                   .fetch(query.index.name, {})
    end

    def format_results(queries, responses)
      queries.each_with_index.with_object({}) do |(query, idx), memo|
        search_result = responses[idx]
        raise TradeTariffBackend::SearchClient::QueryError, search_result.error if search_result.error?

        results = search_result.hits!.hits!
        results.uniq! do |result|
          if result['_source'].key?('reference')
            result['_source']['reference']['id']
          else
            result
          end
        end

        memo.deep_merge!({
          query.match_type => { query.index.type.pluralize => results },
        })
      end
    end
  end
end
