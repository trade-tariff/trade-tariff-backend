module Api
  module V2
    class HeadingsController < ApiController
      before_action :find_heading, only: %i[show changes]

      def show
        service = ::HeadingService::HeadingSerializationService.new(@heading, actual_date)
        render json: service.serializable_hash
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
    end
  end
end
