module Beta
  module Search
    class OpenSearchResult
      include ContentAddressableId

      content_addressable_fields { |search_result| "#{search_result.search_query_parser_result.id}-#{search_result.hit_ids}" }

      delegate :id, to: :search_query_parser_result, prefix: true, allow_nil: true
      delegate :id, to: :goods_nomenclature_query, prefix: true, allow_nil: true
      delegate :id, to: :guide, prefix: true, allow_nil: true
      delegate :id, to: :intercept_message, prefix: true, allow_nil: true
      delegate :id, to: :direct_hit, prefix: true, allow_nil: true

      delegate :goods_nomenclature_item_id, :numeric?, :short_code, to: :goods_nomenclature_query, allow_nil: true

      GUIDE_PERCENTAGE_THRESHOLD = 25

      attr_accessor :took,
                    :timed_out,
                    :hits,
                    :max_score,
                    :search_query_parser_result,
                    :goods_nomenclature_query,
                    :empty_query,
                    :search_reference

      class WithHits
        def self.build(result, search_query_parser_result, goods_nomenclature_query, search_reference)
          search_result = ::Beta::Search::OpenSearchResult.new

          search_result.took = result.took
          search_result.timed_out = result.timed_out
          search_result.max_score = result.hits.max_score
          search_result.hits = result.hits.hits.map(&method(:build_hit))
          search_result.search_query_parser_result = search_query_parser_result
          search_result.goods_nomenclature_query = goods_nomenclature_query
          search_result.empty_query = false
          search_result.search_reference = search_reference

          search_result
        end

        def self.build_hit(hit_result)
          hit = Hashie::TariffMash.new

          hit.score = hit_result._score
          hit.goods_nomenclature_class = hit_result._source.goods_nomenclature_class
          hit.id = hit_result._source.id
          hit.goods_nomenclature_item_id = hit_result._source.goods_nomenclature_item_id
          hit.producline_suffix = hit_result._source.producline_suffix
          hit.description = hit_result._source.description
          hit.description_indexed = hit_result._source.description_indexed
          hit.declarable = hit_result._source.declarable

          case hit.goods_nomenclature_class
          when 'Chapter'
            hit.chapter_description = hit_result._source.description_indexed
            hit.heading_description = nil
          when 'Heading'
            hit.chapter_description = hit_result._source.ancestor_1_description_indexed
            hit.heading_description = hit_result._source.description_indexed
          else
            hit.chapter_description = hit_result._source.ancestor_1_description_indexed
            hit.heading_description = hit_result._source.ancestor_2_description_indexed
          end

          hit.search_references = hit_result._source.search_references
          hit.validity_start_date = hit_result._source.validity_start_date
          hit.validity_end_date = hit_result._source.validity_end_date
          hit.chapter_id = hit_result._source.chapter_id
          hit.heading_id = hit_result._source.heading_id
          hit.ancestors = hit_result._source.ancestors
          hit.ancestor_ids = hit_result._source.ancestors.map(&:id)
          hit.guides = hit_result._source.guides
          hit.guides_ids = hit_result._source.guide_ids
          hit.facet_filters = []
          hit_result._source.keys.grep(/^filter_.*$/).each do |filter|
            filter_classifications = hit_result._source.public_send(filter)
            hit.facet_filters << filter

            hit.public_send("#{filter}=", filter_classifications)
          end
          hit.search_intercept_terms = hit_result._source.search_intercept_terms

          hit
        end
      end

      class NoHits
        def self.build(_result, search_query_parser_result, goods_nomenclature_query, search_reference)
          search_result = ::Beta::Search::OpenSearchResult.new

          search_result.took = 0
          search_result.timed_out = false
          search_result.max_score = 0
          search_result.hits = []
          search_result.search_query_parser_result = search_query_parser_result
          search_result.goods_nomenclature_query = goods_nomenclature_query
          search_result.empty_query = true
          search_result.search_reference = search_reference

          search_result
        end
      end

      def hit_ids
        hits.map(&:id)
      end

      def total_results
        hits.count
      end

      def chapter_statistics
        (@chapter_statistics&.values || []).sort_by(&:score).reverse
      end

      def chapter_statistic_ids
        chapter_statistics.pluck(:id)
      end

      def heading_statistics
        (@heading_statistics&.values || []).sort_by(&:cnt).reverse
      end

      def heading_statistic_ids
        heading_statistics.pluck(:id)
      end

      def guide
        if guide_statistics?
          candidate_guide = guide_statistics.max_by(&:percentage)

          candidate_guide if candidate_guide.percentage > GUIDE_PERCENTAGE_THRESHOLD
        end
      end

      def guide_statistics
        @guide_statistics&.values || []
      end

      def guide_statistics?
        @guide_statistics&.any?
      end

      def facet_filter_statistics
        @facet_filter_statistics || []
      end

      def facet_filter_statistic_ids
        facet_filter_statistics.map(&:id)
      end

      def generate_heading_and_chapter_statistics
        @chapter_statistics, @heading_statistics = Api::Beta::SearchResultStatisticsService.new(hits).call
      end

      def generate_guide_statistics
        @guide_statistics = Api::Beta::GuideStatisticsService.new(hits).call
      end

      def generate_facet_statistics
        @facet_filter_statistics = Api::Beta::SearchFacetStatisticService.new(hits).call
      end

      def redirect!
        @redirect = true
      end

      def redirect?
        !!@redirect
      end

      alias_method :redirect, :redirect?

      def redirect_to
        return nil unless redirect?

        resource_path = if search_reference.present?
                          search_reference.resource_path
                        else
                          id = short_code

                          path = case short_code.length
                                 when 1
                                   id = short_code.rjust(2, '0')
                                   '/chapters/:id'
                                 when 2
                                   '/chapters/:id'
                                 when 4
                                   '/headings/:id'
                                 when 6
                                   '/subheadings/:id0000-80'
                                 when 8
                                   '/subheadings/:id00-80'
                                 when 10
                                   '/commodities/:id'
                                 when 13
                                   if short_code.match?(/\d{10}-\d{2}/)
                                     '/subheadings/:id'
                                   else
                                     id = short_code.first(4)
                                     '/headings/:id'
                                   end
                                 else
                                   id = short_code.first(4)
                                   '/headings/:id'
                                 end

                          path.sub(':id', id)
                        end

        resource_path.prepend('/xi/') if TradeTariffBackend.xi?

        URI.join(TradeTariffBackend.frontend_host, resource_path).to_s
      end

      def intercept_message
        @intercept_message ||= ::Beta::Search::InterceptMessage.build(search_query_parser_result.original_search_query)
      end

      def direct_hit
        @direct_hit ||= DirectHit.build(self)
      end
    end
  end
end
