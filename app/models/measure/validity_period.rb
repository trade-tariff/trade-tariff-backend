# frozen_string_literal: true

class Measure
  # Encapsulates the rules for determining a Measure's effective validity end
  # date, which can come from the measure itself, its generating regulation, or
  # its justification regulation, depending on context.
  class ValidityPeriod
    def initialize(measure)
      @measure = measure
    end

    def end_date
      return measure[:validity_end_date] if measure.national?
      return regulation_capped_end_date if measure_and_regulation_dates_present?
      return measure[:validity_end_date] if measure[:validity_end_date].present? && measure.justification_regulation_present?

      generating_regulation.presence&.effective_end_date
    end

    private

    attr_reader :measure

    def measure_and_regulation_dates_present?
      measure[:validity_end_date].present? &&
        generating_regulation.present? &&
        generating_regulation.effective_end_date.present?
    end

    def regulation_capped_end_date
      [measure[:validity_end_date], generating_regulation.effective_end_date].min
    end

    def generating_regulation
      measure.generating_regulation
    end
  end
end
