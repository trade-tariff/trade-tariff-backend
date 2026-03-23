# frozen_string_literal: true

class Measure
  # Formats a Measure's duty expression in the various representations needed
  # by the API and UI. Keeps presentation logic out of the Measure model.
  class DutyExpressionPresenter
    def initialize(measure)
      @measure = measure
    end

    # Plain space-joined duty expression strings from each component.
    def plain
      components.map(&:duty_expression_str).join(' ')
    end

    # Formatted duty expression, joining each component's formatted string.
    def formatted
      components.map(&:formatted_duty_expression).join(' ')
    end

    # Verbose duty expression with normalised whitespace and number/% formatting.
    def verbose
      raw_verbose
        .gsub(/\s\s/, ' ')           # Replace double spaces with single space
        .gsub(/(\d)\s+%/, '\1%')     # Remove space between number and percentage
    end

    # Resolved duty expression after Meursing component substitution.
    def resolved
      return '' unless measure.send(:resolves_meursing_measures?)

      measure.resolved_measure_components.map(&:formatted_duty_expression).join(' ')
    end

    # Human-readable measurement unit description for supplementary unit measures.
    def supplementary_unit
      measurement_unit = components.first&.measurement_unit
      return nil unless measurement_unit

      "#{measurement_unit.description} (#{measurement_unit.abbreviation})"
    end

    private

    attr_reader :measure

    def components
      measure.measure_components
    end

    def raw_verbose
      components.map(&:verbose_duty_expression).join(' ')
    end
  end
end
