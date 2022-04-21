require 'goods_nomenclature_mapper'

module Api
  module V2
    class HeadingsController < ApiController
      before_action :find_heading

      def show
        service = ::HeadingService::HeadingSerializationService.new(@heading, actual_date)
        render json: service.serializable_hash
      end

      def commodities
        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::CommoditySerializer.new(cached_commodities).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=headings-#{params[:id]}-commodities-#{actual_date.iso8601}.csv",
            )
          end

          format.all do
            service = ::HeadingService::HeadingSerializationService.new(@heading, actual_date)
            render json: service.serializable_hash
          end
        end
      end

      def changes
        key = "heading-#{@heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@heading.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        render json: Api::V2::Changes::ChangeSerializer.new(@changes.changes, options).serializable_hash
      end

      private

      def find_heading
        @heading = Heading.actual
                          .non_grouping
                          .where(goods_nomenclatures__goods_nomenclature_item_id: heading_id)
                          .take

        raise Sequel::RecordNotFound if @heading.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def heading_id
        "#{params[:id]}000000"
      end

      def cached_commodities
        cached_heading.commodities
      end

      def cached_heading
        HeadingService::CachedHeadingService.new(@heading, actual_date).serializable_hash
      end
    end
  end
end
