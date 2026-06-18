module Api
  module Admin
    class CustomsTariffUpdatesController < AdminController
      def index
        render json: Api::Admin::CustomsTariffUpdateSerializer.new(
          updates.to_a,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

      def show
        render json: Api::Admin::CustomsTariffUpdateSerializer.new(customs_tariff_update, is_collection: false).serializable_hash
      end

      private

      def updates
        @updates ||= CustomsTariffUpdate
          .order(Sequel.desc(:validity_start_date))
          .paginate(current_page, per_page)
      end

      def pagination_meta
        {
          pagination: {
            page: current_page,
            per_page:,
            total_count: updates.pagination_record_count,
          },
        }
      end

      def customs_tariff_update
        @customs_tariff_update ||= CustomsTariffUpdate.where(version: params[:version]).first.tap do |u|
          raise Sequel::RecordNotFound unless u
        end
      end
    end
  end
end
