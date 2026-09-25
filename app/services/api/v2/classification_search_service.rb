module Api
  module V2
    class ClassificationSearchService
      include Api::Internal::QueryProcessing

      DEFAULT_LIMIT = 30
      MAX_LIMIT = 50
      MAX_FILTER_PREFIXES = 10
      FILTER_PREFIX_FORMAT = /\A\d{2,10}\z/

      def initialize(params = {})
        @params = params
        sanitiser_result = Api::Internal::InputSanitiser.new(params[:q]).call

        if sanitiser_result[:errors]
          @sanitiser_errors = sanitiser_result
          @query = ''
        else
          @query = process_query(sanitiser_result[:query])
        end
      end

      def call
        return @sanitiser_errors if @sanitiser_errors

        prefix_errors = filter_prefix_errors
        return prefix_errors if prefix_errors

        return empty_response if @query.blank?

        ::Search::Instrumentation.search(request_id:, query: @query, search_type: 'classification') do
          # A caller that sends an expanded query has already rewritten the
          # product in tariff terms. Retrieval must rank on that rewrite. If the
          # raw query stays as `query`, the OpenSearch leg makes one boosted
          # clause per raw word, and those clauses outvote the rewrite. The
          # search events above still record the query the caller sent.
          result = HybridRetrievalService.call(
            query: expanded_query || @query,
            expanded_query: expanded_query,
            as_of: parse_date(@params[:as_of]),
            request_id: request_id,
            limit: limit,
            filter_prefixes: filter_prefixes,
            search_non_declarables: search_non_declarables,
            search_type: 'classification',
          )

          # Hybrid retrieval fuses two legs of up to `limit` items each, so it
          # returns up to twice the limit this caller asked for. Cap it here.
          # The fused set stays whole inside retrieval, because guided search
          # uses the same service and needs every candidate.
          results = result.results.first(limit)

          response = ClassificationSearchResultSerializer.serialize(
            results,
            meta: response_meta(result, results),
          )
          completion = {
            result_count: results.size,
            results_type: 'hybrid',
            max_score: results.map(&:score).compact.max,
          }
          [response, completion]
        end
      end

    private

      def empty_response
        {
          data: [],
          meta: {
            request_id: request_id,
            retrieval_method: 'hybrid',
            expanded_query: expanded_query || @query,
            result_count: 0,
            max_score: nil,
            search_failures: Array(TradeTariffRequest.search_failures),
          },
        }
      end

      # `results` is the capped set this response returns, so the counts match
      # what the caller receives rather than what retrieval fetched.
      def response_meta(result, results)
        {
          request_id: request_id,
          retrieval_method: 'hybrid',
          expanded_query: result.expanded_query,
          result_count: results.size,
          max_score: results.map(&:score).compact.max,
          search_failures: Array(TradeTariffRequest.search_failures),
        }
      end

      def expanded_query
        @params[:expanded_query].to_s.strip.presence
      end

      def request_id
        @request_id ||= @params[:request_id].presence || TradeTariffRequest.request_id.presence || SecureRandom.uuid
      end

      def limit
        raw_limit = @params[:limit].presence || DEFAULT_LIMIT
        [[raw_limit.to_i, 1].max, MAX_LIMIT].min
      end

      # Restricts retrieval to one or more goods nomenclature code prefixes, so a
      # caller can run a second, narrower search inside a chapter or heading it
      # has already established. Accepts an array or a comma separated string.
      def filter_prefixes
        @filter_prefixes ||= Array(raw_filter_prefixes).map { |prefix| prefix.to_s.strip }.compact_blank.uniq
      end

      def raw_filter_prefixes
        raw = @params[:filter_prefixes]
        return raw.to_s.split(',') if raw.is_a?(String)

        raw
      end

      def filter_prefix_errors
        return nil if filter_prefixes.empty?

        if filter_prefixes.size > MAX_FILTER_PREFIXES
          return filter_prefix_error("filter_prefixes accepts at most #{MAX_FILTER_PREFIXES} prefixes")
        end

        invalid = filter_prefixes.reject { |prefix| prefix.match?(FILTER_PREFIX_FORMAT) }
        return nil if invalid.empty?

        filter_prefix_error("filter_prefixes must be 2 to 10 digit codes, got: #{invalid.join(', ')}")
      end

      def filter_prefix_error(detail)
        {
          errors: [
            {
              status: '422',
              title: 'Invalid filter_prefixes',
              detail: detail,
              source: { pointer: '/data/attributes/filter_prefixes' },
            },
          ],
        }
      end

      # Tri-state on purpose. nil means "the caller did not ask", and every
      # retrieval leg then falls back to the search_non_declarables admin
      # setting, so existing callers keep today's behaviour untouched.
      def search_non_declarables
        raw = @params[:search_non_declarables]
        return nil if raw.nil? || raw.to_s.strip.empty?

        ActiveModel::Type::Boolean.new.cast(raw)
      end
    end
  end
end
