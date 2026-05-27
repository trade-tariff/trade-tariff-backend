module Api
  module Admin
    class CustomsTariffUpdatesController < AdminController
      def index
        updates = CustomsTariffUpdate.order(Sequel.desc(:validity_start_date)).all
        render json: Api::Admin::CustomsTariffUpdateSerializer.new(updates, is_collection: true).serializable_hash
      end

      def show
        render json: Api::Admin::CustomsTariffUpdateSerializer.new(customs_tariff_update, is_collection: false).serializable_hash
      end

      private

      def customs_tariff_update
        @customs_tariff_update ||= CustomsTariffUpdate.where(version: params[:version]).first.tap do |u|
          raise Sequel::RecordNotFound unless u
        end
      end
    end
  end
end
