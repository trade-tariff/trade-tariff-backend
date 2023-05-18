module Reporting
  class DeclarableDuties
    class PresentedMeasure < WrapDelegator
      attr_accessor :trackedmodel_ptr_id

      def <=>(other)
        [
          measure_type_id,
          geographical_area_id,
          ordernumber || '',
          additional_code_type_id || '',
          additional_code_id || '',
        ] <=> [
          other.measure_type_id,
          other.geographical_area_id,
          other.ordernumber || '',
          other.additional_code_type_id || '',
          other.additional_code_id || '',
        ]
      end

      def measure__sid
        measure_sid
      end

      def measure__type__id
        measure_type_id
      end

      def measure__type__description
        measure_type.description
      end

      def measure__additional_code__code
        additional_code&.code
      end

      def measure__additional_code__description
        additional_code&.description
      end

      def measure__duty_expression
        duty_expression
      end

      def measure__effective_start_date
        validity_start_date&.to_date&.iso8601
      end

      def measure__effective_end_date
        validity_end_date&.to_date&.iso8601
      end

      def measure_reduction_indicator
        reduction_indicator
      end

      def measure__footnotes
        footnotes.map(&:code).join('|').presence || nil
      end

      def measure__conditions
        measure_conditions.map { |measure_condition|
          condition = []
          condition << "condition:#{measure_condition.condition_code}"
          condition << "certificate:#{measure_condition.document_code}" if measure_condition.document_code.present?
          condition << "action:#{measure_condition.action_code}"
          condition.join(',')
        }.join('|').presence || nil
      end

      def measure__geographical_area__sid
        geographical_area_sid
      end

      def measure__geographical_area__id
        geographical_area_id
      end

      def measure__geographical_area__description
        geographical_area.description
      end

      def measure__excluded_geographical_areas__ids
        ids = measure_excluded_geographical_areas.map { |measure_excluded_geographical_area|
          measure_excluded_geographical_area.geographical_area.geographical_area_id
        }.presence || []

        ids.join('|')
      end

      def measure__excluded_geographical_areas__descriptions
        measure_excluded_geographical_areas.map { |exclusion| exclusion.geographical_area.description }.join('|')
      end

      def measure__quota__order_number
        ordernumber
      end

      def measure__quota__available
        return '' if ordernumber.blank?
        return 'See RPA' if ordernumber.starts_with?(*QuotaOrderNumber::LICENSED_QUOTA_PREFIXES)
        return 'Invalid' if quota_definition.nil?

        quota_definition.balance.to_i.positive? ? 'Open' : 'Exhausted'
      end

      def measure__regulation__id
        measure_generating_regulation_id
      end

      def measure__regulation__url
        Api::V2::Measures::MeasureLegalActPresenter.new(generating_regulation, self).regulation_url
      end
    end
  end
end
