module Api
  module V1
    class UpdatesController < ApiController
      before_action :collection, only: :index

      def index; end

      def latest
        @updates = TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds

        respond_with @updates
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
    end
  end
end
