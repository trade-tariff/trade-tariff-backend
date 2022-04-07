module Api
  module V2
    class FootnotesController < ApiController
      before_action :find_footnotes

      def search
        options = {}
        options[:include] = [:measures, 'measures.goods_nomenclature', :goods_nomenclatures]
        render json: Api::V2::Footnotes::FootnoteSerializer.new(@footnotes, options.merge(serialization_meta)).serializable_hash
      end

      private

      def find_footnotes
        TimeMachine.now do
          @footnotes = search_service.perform
        end
      end

      def search_service
        @search_service ||= FootnoteSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page:,
              total_count: search_service.pagination_record_count
            }
          }
        }
      end
    end
  end
end
