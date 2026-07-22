module Api
  module V2
    class MeasuresController < ApiController
      def show
        render json: Api::V2::MeasureSerializer.new(presented_measure, serializer_options)
      end

      def search
        if summary_mode?
          render json: { meta: search_service.summarize }
        else
          render json: Api::V2::Measures::MeasureSearchResultSerializer.new(
            measures,
            meta: pagination_meta,
          ).serializable_hash
        end
      end

    private

      def measures
        search_service.call
      end

      def search_service
        @search_service ||= MeasureSearchService.new(
          filters: filter_params,
          page: current_page,
          per_page:,
          as_of:,
        )
      end

      def filter_params
        params.fetch(:filter, {}).permit(
          :geographical_area_id,
          :has_no_geographical_exclusions,
          :has_no_exemption_conditions,
          :has_ad_valorem,
          :trade_direction,
          :commodity_code_prefix,
          :regulation_id,
          measure_type_series: [],
          measure_type_ids: [],
          measure_condition_codes: [],
        ).to_h.with_indifferent_access
      end

      def pagination_meta
        {
          as_of: as_of.to_date.iso8601,
          pagination: {
            page: current_page,
            per_page:,
            total_count: search_service.pagination_record_count,
          },
        }
      end

      def summary_mode?
        params[:summary].to_s == 'true'
      end

      def as_of
        @as_of ||= params[:as_of].present? ? Date.parse(params[:as_of]) : Time.current
      rescue ArgumentError
        Time.current
      end

      def per_page
        Integer(params[:per_page] || 25).clamp(1, MeasureSearchService::MAX_PER_PAGE)
      rescue ArgumentError
        25
      end

      def presented_measure
        measure = Measure.actual
                         .where(measure_sid: params[:id])
                         .take

        @presented_measure = Api::V2::Measures::MeasurePresenter.new(measure, measure.goods_nomenclature)
      end

      def serializer_options
        {
          include: %w[
            goods_nomenclature
            duty_expression
            measure_type
            legal_acts
            measure_generating_legal_act
            justification_legal_act
            measure_conditions
            measure_conditions.measure_condition_components
            measure_components
            geographical_area
            geographical_area.contained_geographical_areas
            excluded_geographical_areas
            footnotes
            additional_code
            order_number
            order_number.definition
          ],
        }
      end
    end
  end
end
