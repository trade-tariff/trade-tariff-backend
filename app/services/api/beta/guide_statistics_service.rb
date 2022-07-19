module Api
  module Beta
    class GuideStatisticsService
      def initialize(goods_nomenclature_hits)
        @goods_nomenclature_hits = goods_nomenclature_hits
      end

      def call
        heading_stats.each_with_object({}) do |heading_stat, guide_statistics|
          heading_stat[:guides].each do |guide|
            guide_statistics[guide.id] ||= guide.dup
            guide_statistics[guide.id].count ||= 0
            guide_statistics[guide.id].percentage ||= 0
            guide_statistics[guide.id].count += heading_stat[:count]
            guide_statistics[guide.id].percentage += heading_stat[:percentage]
          end
        end
      end

      private

      attr_reader :goods_nomenclature_hits

      def heading_stats
        total_hits = goods_nomenclature_hits.count

        hits_by_heading_count_with_guides.each_with_object([]) do |(heading_id, hit_results), guide_heading_stats|
          guides = hit_results[:guides]
          count = hit_results[:count]
          percentage = 100 / total_hits * count

          guide_heading_stats << {
            heading_id:,
            count:,
            percentage:,
            guides:,
          }
        end
      end

      def hits_by_heading_count_with_guides
        goods_nomenclature_hits.each_with_object({}) do |hit, acc|
          acc[hit.heading_id] ||= { count: 0 }
          acc[hit.heading_id][:count] += 1
          acc[hit.heading_id][:guides] ||= hit.guides
        end
      end

      def guides_for(heading_id)
        goods_nomenclature_item_id = heading_id + '0' * 6

        goods_nomenclature_hits.find { |hit| hit.goods_nomenclature_item_id == goods_nomenclature_item_id }.guides
      end
    end
  end
end
