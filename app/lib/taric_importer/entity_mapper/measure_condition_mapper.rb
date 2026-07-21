# frozen_string_literal: true

class TaricImporter
  class EntityMapper
    class MeasureConditionMapper < BaseMapper
      self.entity_class = 'MeasureCondition'

      def before_build(attributes, operation)
        return attributes unless operation == :create

        MeasureCondition.assign_national_sid_if_missing(attributes)
      end
    end
  end
end
