module HeadingService
  module Serialization
    class NondeclarableService
      OPTIONS = {
        is_collection: false,
        include: [
          :section,
          :chapter,
          'chapter.guides',
          :footnotes,
          :commodities,
          'commodities.overview_measures',
          'commodities.overview_measures.duty_expression',
          'commodities.overview_measures.measure_type',
          'commodities.overview_measures.additional_code',
        ],
      }.freeze

      attr_reader :heading, :actual_date

      delegate :serializable_hash, to: :serializer

      def initialize(heading, actual_date)
        @heading = heading
        @actual_date = actual_date
      end

    private

      def cache_heading
        HeadingService::CachedHeadingService
          .new(heading, actual_date)
          .serializable_hash
      end

      def serializer
        Api::V2::Headings::HeadingSerializer
          .new(cache_heading, OPTIONS)
      end
    end
  end
end
