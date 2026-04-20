# frozen_string_literal: true

class Measure
  # Resolves the full set of components for a Measure, including condition
  # components and Meursing-substituted components. Keeps component aggregation
  # logic out of the Measure model.
  class ComponentResolver
    EXCISE_ALCOHOL_COERCION_DATE = TradeTariffBackend.respond_to?(:excise_alcohol_coercian_starts_from) ? TradeTariffBackend.excise_alcohol_coercian_starts_from : nil

    def initialize(measure)
      @measure = measure
    end

    # All components across conditions, base components, and resolved Meursing components.
    def all_components
      condition_components + measure.measure_components + resolved_components
    end

    # Components used when computing units (includes measure_conditions after
    # the excise alcohol coercion date).
    def all_unit_components
      return all_components if pre_excise_coercion_date?

      all_components + measure.measure_conditions
    end

    # Flat list of components from all measure conditions.
    def condition_components
      @condition_components ||= measure.measure_conditions.flat_map(&:measure_condition_components)
    end

    # Resolved measure components after Meursing substitution (may be empty).
    def resolved_components
      @resolved_components ||= if resolves_meursing?
                                 MeursingMeasureComponentResolverService.new(measure, meursing_measures).call
                               else
                                 []
                               end
    end

    def resolves_meursing?
      measure.meursing? &&
        meursing_additional_code_id.present? &&
        meursing_measures.present?
    end

    # Returns all unique units expressed by any component.
    def units
      all_unit_components.each_with_object(Set.new) { |component, acc|
        next unless component.expresses_unit?

        unit = component.unit_for(measure)
        acc << unit if unit.present?
      }.to_a
    end

    def ad_valorem?
      ad_valorem_resource?(:measure_components) ||
        ad_valorem_resource?(:measure_conditions) ||
        ad_valorem_resource?(:resolved_measure_components)
    end

    def expresses_unit?
      measure.measure_type.expresses_unit? && components_express_unit?
    end

    def meursing_measures
      @meursing_measures ||= MeursingMeasureFinderService.new(measure, meursing_additional_code_id).call
    end

    private

    attr_reader :measure

    def pre_excise_coercion_date?
      point_in_time = measure.respond_to?(:point_in_time) ? measure.point_in_time : nil
      EXCISE_ALCOHOL_COERCION_DATE && point_in_time.present? && point_in_time < EXCISE_ALCOHOL_COERCION_DATE
    end

    def meursing_additional_code_id
      TradeTariffRequest.meursing_additional_code_id
    end

    def components_express_unit?
      measure.measure_components.any?(&:expresses_unit?) ||
        measure.measure_conditions.any?(&:expresses_unit?) ||
        condition_components.any?(&:expresses_unit?) ||
        resolved_components.any?(&:expresses_unit?)
    end

    def ad_valorem_resource?(resource)
      resources = measure.public_send(resource)
      resources.count == 1 && resources.first.ad_valorem?
    end
  end
end
