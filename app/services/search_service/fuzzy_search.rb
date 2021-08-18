class SearchService
  class FuzzySearch < BaseSearch
    def search!
      begin
        @results ||= begin
          FuzzySearchResult.new(query_string, date).each_with_object({}) do |(match_type, search_index, results), memo|

            results.uniq! do |result|
              if result['_source'].has_key?('reference')
                result['_source']['reference']['id']
              else
                result
              end
            end

            memo.deep_merge!({
              match_type => { search_index.type.pluralize => results }
            })
          end
        end
      rescue Elasticsearch::Transport::Transport::Error
        # rescue from malformed queries, return empty resultset in that case
        BLANK_RESULT
      end

      self
    end

    def serializable_hash
      {
        type: 'fuzzy_match',
      }.merge(results)
    end
  end
end
