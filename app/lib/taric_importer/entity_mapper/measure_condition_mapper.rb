# frozen_string_literal: true

class TaricImporter
  class EntityMapper
    class MeasureConditionMapper < BaseMapper
      self.entity_class = 'MeasureCondition'

      def before_build(attributes, operation)
        return attributes unless operation == :create
        return attributes if attributes['measure_condition_sid'].present?

        attributes['measure_condition_sid'] = national_sid_counter.next_for(MeasureCondition)
        attributes
      end
    end
  end
end
