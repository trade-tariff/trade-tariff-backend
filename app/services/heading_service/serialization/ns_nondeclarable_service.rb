module HeadingService
  module Serialization
    class NsNondeclarableService
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

      attr_reader :heading

      delegate :serializable_hash, to: :serializer

      def initialize(heading)
        @heading = heading
      end

    private

      def presented_heading
        Api::V2::Headings::HeadingPresenter.new(heading)
      end

      def serializer
        Api::V2::Headings::HeadingSerializer
          .new(presented_heading, OPTIONS)
      end
    end
  end
end
