module Api
  module Admin
    class UpdatesController < ApiController
      before_action :collection, only: :index

      def index
        render json: Api::Admin::TariffUpdateSerializer.new(@collection.to_a, serialization_meta).serializable_hash
      end

      private

      def collection
        @collection ||= TariffSynchronizer::BaseUpdate.eager(:presence_errors)
          .descending
          .exclude(update_type: 'TariffSynchronizer::ChiefUpdate')
          .paginate(current_page, per_page)
      end

      def per_page
        60
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: @collection.pagination_record_count,
            },
          },
        }
      end
    end
  end
end
