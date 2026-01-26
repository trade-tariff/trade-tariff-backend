class SearchService
  class FuzzySearch < BaseSearch
    INDEX_SIZE_MAX = 10_000 # OpenSearch default pagination limit

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

    # We craft Elasticsearch queries in streamlined way, but
    # certain queries need additional query details to be provided.
    # These details can be specified in query_options
    def query_options
      {
        goods_nomenclature_match: {
          Search::SectionIndex.new.name => { fields: %w[title] },
        },
      }
    end

    def build_queries
      @build_queries ||= TradeTariffBackend.search_indexes
        .reject(&:exclude_from_search_results?)
        .flat_map do |search_index|
          [
            GoodsNomenclatureQuery.new(query_string, date, search_index),
            ReferenceQuery.new(query_string, date, search_index),
          ]
        end
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
