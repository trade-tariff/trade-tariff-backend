# frozen_string_literal: true

class Measure
  # Defines the natural sort order for measures used when building sorted
  # measure collections. Measures are ordered by geographical area,
  # measure type, additional code, order number, and effective end date
  # (with nil values sorting last in all positions).
  module Orderable
    def sort_key
      @sort_key ||= [
        geographical_area_id,
        measure_type_id,
        additional_code_type_id,
        additional_code_id,
        ordernumber,
        values[
          values.key?(:effective_end_date) ? :effective_end_date : :validity_end_date,
        ],
      ]
    end

    def <=>(other)
      sort_key.each.with_index do |value, index|
        if value.nil?
          next if other.sort_key[index].nil?

          return 1
        elsif other.sort_key[index].nil?
          return -1
        else
          comparison_result = value <=> other.sort_key[index]

          return comparison_result unless comparison_result.zero?
        end
      end

      0
    end
  end
end
