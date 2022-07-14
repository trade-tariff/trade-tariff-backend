module Api
  module Beta
    class SearchResultStatisticsService
      def initialize(goods_nomenclature_hits)
        @goods_nomenclature_hits = goods_nomenclature_hits
        @chapter_statistics = {}
        @heading_statistics = {}
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
        goods_nomenclature_hits.each do |hit|
          chapter_statistic = @chapter_statistics[hit.chapter_id] ||= {}

          @chapter_statistics[hit.chapter_id] = accumulate_chapter_statistic_for(hit, chapter_statistic)
        end

        @chapter_statistics = Hashie::TariffMash.new(@chapter_statistics)
      end

      def generate_heading_statistics
        goods_nomenclature_hits_with_headings.each do |hit|
          heading_statistic = @heading_statistics[hit.heading_id] ||= {}

          @heading_statistics[hit.heading_id] = accumulate_heading_statistic_for(hit, heading_statistic)
        end

        @heading_statistics = Hashie::TariffMash.new(@heading_statistics)
      end

      def goods_nomenclature_hits_with_headings
        goods_nomenclature_hits.reject do |hit|
          hit.goods_nomenclature_class.chapter?
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

        goods_nomenclature_hits_with_headings.each do |goods_nomenclature_hit|
          if yield goods_nomenclature_hit
            scores << goods_nomenclature_hit.score
          end
        end

        scores.inject(0, :+) / scores.length
      end

      def accumulate_chapter_statistic_for(hit, chapter_statistic)
        chapter_statistic['id'] ||= hit.chapter_id
        chapter_statistic['description'] ||= hit.chapter_description
        chapter_statistic['score'] ||= 0
        chapter_statistic['cnt'] ||= 0
        chapter_statistic['cnt'] += 1
        chapter_statistic['score'] += hit.score
        chapter_statistic['avg'] ||= mean_average_chapter_score_for(hit.chapter_id)
        chapter_statistic
      end

      def accumulate_heading_statistic_for(hit, heading_statistic)
        heading_statistic['id'] ||= hit.heading_id
        heading_statistic['description'] ||= hit.heading_description
        heading_statistic['chapter_id'] ||= hit.chapter_id
        heading_statistic['chapter_description'] ||= hit.chapter_description
        heading_statistic['score'] ||= 0
        heading_statistic['score'] += hit.score
        heading_statistic['cnt'] ||= 0
        heading_statistic['cnt'] += 1
        heading_statistic['avg'] ||= mean_average_heading_score_for(hit.heading_id)
        heading_statistic['chapter_score'] ||= @chapter_statistics[hit.chapter_id]['score']
        heading_statistic
      end
    end
  end
end
