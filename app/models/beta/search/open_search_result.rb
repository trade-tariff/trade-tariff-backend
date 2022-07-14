module Beta
  module Search
    class OpenSearchResult
      delegate :id, to: :chapter_statistics, prefix: true, allow_nil: true
      delegate :id, to: :heading_statistics, prefix: true, allow_nil: true
      delegate :id, to: :search_query_parser_result, prefix: true, allow_nil: true

      attr_accessor :took,
                    :timed_out,
                    :hits,
                    :max_score,
                    :search_query_parser_result

      class << self
        def build(result, search_query_parser_result)
          search_result = new

          search_result.took = result.took
          search_result.timed_out = result.timed_out
          search_result.max_score = result.hits.max_score
          search_result.hits = result.hits.hits.map(&method(:build_hit))
          search_result.search_query_parser_result = search_query_parser_result

          search_result
        end

        def build_hit(hit_result)
          hit = Hashie::TariffMash.new

          hit.score = hit_result._score
          hit.goods_nomenclature_class = ActiveSupport::StringInquirer.new(hit_result._source.goods_nomenclature_class)
          hit.id = hit_result._source.id
          hit.goods_nomenclature_item_id = hit_result._source.goods_nomenclature_item_id
          hit.producline_suffix = hit_result._source.producline_suffix
          hit.description = hit_result._source.description
          hit.description_indexed = hit_result._source.description_indexed
          hit.chapter_description = hit_result._source.chapter_description
          hit.heading_description = hit_result._source.heading_description
          hit.search_references = hit_result._source.search_references
          hit.validity_start_date = hit_result._source.validity_start_date
          hit.validity_end_date = hit_result._source.validity_end_date
          hit.chapter_id = hit_result._source.chapter_id
          hit.heading_id = hit_result._source.heading_id
          hit.ancestors = hit_result._source.ancestors
          hit.ancestor_ids = hit_result._source.ancestors.map(&:id)

          hit
        end
      end

      def id
        digestable = "#{search_query_parser_result.id}-#{hit_ids}"

        Digest::MD5.hexdigest(digestable)
      end

      def hit_ids
        hits.map(&:id)
      end

      def total_results
        hits.count
      end

      def chapter_statistics
        @chapter_statistics&.values || []
      end

      def chapter_statistic_ids
        chapter_statistics.pluck(:id)
      end

      def heading_statistics
        @heading_statistics&.values || []
      end

      def heading_statistic_ids
        heading_statistics.pluck(:id)
      end

      def generate_statistics
        @chapter_statistics, @heading_statistics = Api::Beta::SearchResultStatisticsService.new(hits).call
      end
    end
  end
end
