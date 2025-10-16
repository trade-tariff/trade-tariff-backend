class CdsImporter
  class ExcelWriter
    class Measure < BaseMapper
      def sheet_name
        'Measures'
      end

      def table_span
        %w[A M]
      end

      def column_widths
        [30, 20, 20, 40, 40, 20, 20, 20, 40, 30, 30, 100, 30]
      end

      def heading
        ['Action',
         'Commodity code',
         'Additional code',
         'Measure type',
         'Geographical area',
         'Quota order number',
         'Start date',
         'End date',
         'Duty',
         'Excluded areas',
         'Footnotes',
         'Conditions',
         'SID']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        measure = grouped['Measure'].first
        measure_components = grouped['MeasureComponent']
        excluded_geo_areas = grouped['MeasureExcludedGeographicalArea']
        footnotes = grouped['FootnoteAssociationMeasure']
        conditions = grouped['MeasureCondition']

        ["#{expand_operation(measure)} measure",
         measure.goods_nomenclature_item_id,
         measure.additional_code_type_id.to_s + measure.additional_code_id.to_s,
         measure_type(measure.measure_type_id),
         geographical_area(measure.geographical_area_sid),
         measure.ordernumber,
         format_date(measure.validity_start_date),
         format_date(measure.validity_end_date),
         combined_duty(measure_components),
         exclusion_string(excluded_geo_areas),
         footnote_string(footnotes),
         measure_condition_string(conditions),
         measure.measure_sid]
      end

      private

      def measure_type(measure_type_id)
        mt = ::MeasureType.find(measure_type_id: measure_type_id)
        if mt
          "#{measure_type_id}(#{mt.description})"
        else
          measure_type_id.to_s
        end
      end

      def geographical_area(geo_area_sid)
        ga = ::GeographicalArea
          .where(geographical_area_sid: geo_area_sid)
          .eager(:geographical_area_descriptions).first

        if ga
          "#{ga.geographical_area_id}(#{ga.description})"
        else
          geo_area_sid.to_s
        end
      end

      def measure_condition_string(conditions)
        return '' if conditions.blank?

        conditions
          .reject { |c| c.operation == 'D' }
          .map    { |c| condition_string(c) }
          .reject(&:empty?)
          .join(' ')
      end

      def condition_code_description(condition_code)
        ::MeasureConditionCodeDescription.find(condition_code: condition_code)&.description || ''
      end

      def action_code_description(action_code)
        ::MeasureActionDescription.find(action_code: action_code)&.description || ''
      end

      def get_measurement_unit(code)
        ::MeasurementUnitDescription.find(measurement_unit_code: code)&.description || ''
      end

      def condition_string(condition)
        certificate = "#{condition.certificate_type_code}#{condition.certificate_code}".strip
        certificate = 'n/a' if certificate.blank?

        output = ''
        output << "Certificate: #{certificate}, "
        output << "Condition code: #{condition.condition_code} (#{condition_code_description(condition.condition_code)}), "
        output << "Action code: #{condition.action_code} (#{action_code_description(condition.action_code)})\n"

        output
      end

      def footnote_string(footnotes)
        return '' if footnotes.blank?

        footnotes
          .reject { |c| c.operation == 'D' }
          .map    { |c| "#{c.footnote_type_id}#{c.footnote_id}" }
          .join(', ')
      end

      def exclusion_string(excluded_geo_areas)
        return '' if excluded_geo_areas.blank?

        excluded_geo_areas
          .reject { |c| c.operation == 'D' }
          .map(&:excluded_geographical_area)
          .join(', ')
      end

      def combined_duty(measure_components)
        return '' if measure_components.blank?

        measure_components
          .reject { |c| c.operation == 'D' }
          .map    { |c| duty_string(c) }
          .reject(&:empty?)
          .join(' ')
      end

      def duty_string(measure_component)
        duty_string = ''

        case measure_component.duty_expression_id
        when '01'
          duty_string << build_duty_string(measure_component)
        when '04', '19', '20'
          duty_string << build_duty_string(measure_component, prefix: '+ ')
        when '15'
          duty_string << build_duty_string(measure_component, prefix: 'MIN ')
        when '17', '35'
          duty_string << build_duty_string(measure_component, prefix: 'MAX ')
        when '12'
          duty_string << ' + AC'
        when '14'
          duty_string << ' + ACR'
        when '21'
          duty_string << ' + SD'
        when '25'
          duty_string << ' + SDR'
        when '27'
          duty_string << ' + FD'
        when '29'
          duty_string << ' + FDR'
        when '99'
          duty_string << measure_component.measurement_unit_code
        else
          Rails.logger.warn "Unexpected duty expression found #{measure_component.duty_expression_id}"
        end

        duty_string.squeeze!(' ')
        duty_string
      end

      def get_qualifier(measurement_unit_qualifier_code)
        case measurement_unit_qualifier_code
        when 'A' then 'tot alc'
        when 'C' then '1 000'
        when 'E' then 'net drained wt'
        when 'G' then 'gross'
        when 'I' then 'biodiesel'
        when 'M' then 'net dry'
        when 'P' then 'lactic matter'
        when 'R' then 'std qual'
        when 'S' then 'raw sugar'
        when 'T' then 'dry lactic matter'
        when 'X' then 'hl'
        when 'Z' then '% sacchar.'
        else ''
        end
      end

      def build_duty_string(measure_component, prefix: '')
        duty_string = ''
        if measure_component.monetary_unit_code.to_s.empty?
          duty_string << "#{prefix}#{sprintf('%.4f', measure_component.duty_amount)}%"
        else
          duty_string << "#{prefix}#{sprintf('%.4f', measure_component.duty_amount)} #{measure_component.monetary_unit_code}"
          if measure_component.measurement_unit_code.to_s != ''
            duty_string << " / #{get_measurement_unit(measure_component.measurement_unit_code)}"
            if measure_component.measurement_unit_qualifier_code.to_s != ''
              duty_string << " / #{get_qualifier(measure_component.measurement_unit_qualifier_code)}"
            end
          end
        end
        duty_string
      end
    end
  end
end
