module Api
  module Beta
    class SearchResultStatisticsService
      def initialize(goods_nomenclature_hits)
        @goods_nomenclature_hits = goods_nomenclature_hits
        @chapter_statistics = Hashie::TariffMash.new
        @heading_statistics = Hashie::TariffMash.new
      end

      def call
        search_result_statistics = []

        search_result_statistics << generate_chapter_statistics
        search_result_statistics << generate_heading_statistics

        search_result_statistics
      end

      private

      attr_reader :goods_nomenclature_hits

      def generate_chapter_statistics
        goods_nomenclature_hits.each do |goods_nomenclature_hit|
          @chapter_statistics[goods_nomenclature_hit.chapter_id] ||= Hashie::TariffMash.new
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['id'] ||= goods_nomenclature_hit.chapter_id
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['description'] ||= goods_nomenclature_hit.chapter_description
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['score'] ||= 0
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['cnt'] ||= 0
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['cnt'] += 1
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['score'] += goods_nomenclature_hit.score
          @chapter_statistics[goods_nomenclature_hit.chapter_id]['avg'] ||= mean_average_chapter_score_for(goods_nomenclature_hit.chapter_id)
        end

        @chapter_statistics
      end

      def generate_heading_statistics
        accumulations = 0
        goods_nomenclature_hits_with_headings.each do |goods_nomenclature_hit|
          accumulations += 1
          @heading_statistics[goods_nomenclature_hit.heading_id] ||= Hashie::TariffMash.new
          @heading_statistics[goods_nomenclature_hit.heading_id]['id'] ||= goods_nomenclature_hit.heading_id
          @heading_statistics[goods_nomenclature_hit.heading_id]['description'] ||= goods_nomenclature_hit.heading_description
          @heading_statistics[goods_nomenclature_hit.heading_id]['chapter_id'] ||= goods_nomenclature_hit.chapter_id
          @heading_statistics[goods_nomenclature_hit.heading_id]['chapter_description'] ||= goods_nomenclature_hit.chapter_description
          @heading_statistics[goods_nomenclature_hit.heading_id]['score'] ||= 0
          @heading_statistics[goods_nomenclature_hit.heading_id]['score'] += goods_nomenclature_hit.score
          @heading_statistics[goods_nomenclature_hit.heading_id]['cnt'] ||= 0
          @heading_statistics[goods_nomenclature_hit.heading_id]['cnt'] += 1
          @heading_statistics[goods_nomenclature_hit.heading_id]['avg'] ||= mean_average_heading_score_for(goods_nomenclature_hit.heading_id)
          @heading_statistics[goods_nomenclature_hit.heading_id]['chapter_score'] ||= @chapter_statistics[goods_nomenclature_hit.chapter_id]['score']
        end

        @heading_statistics
      end

      def goods_nomenclature_hits_with_headings
        goods_nomenclature_hits.reject do |goods_nomenclature_hit|
          goods_nomenclature_hit.goods_nomenclature_class.chapter?
        end
      end

      def mean_average_heading_score_for(heading_id)
        mean_average_scores do |goods_nomenclature_hit|
          goods_nomenclature_hit.heading_id == heading_id
        end
      end

      def mean_average_chapter_score_for(chapter_id)
        mean_average_scores do |goods_nomenclature_hit|
          goods_nomenclature_hit.chapter_id == chapter_id
        end
      end

      def mean_average_scores
        scores = []
        count = 0

        goods_nomenclature_hits_with_headings.each do |goods_nomenclature_hit|
          if yield goods_nomenclature_hit
            scores << goods_nomenclature_hit.score
            count += 1
          end
        end

        scores.inject(0, :+) / count
      end
    end
  end
end
