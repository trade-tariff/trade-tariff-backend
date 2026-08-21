# frozen_string_literal: true

class TaricImporter
  class EntityMapper
    class MeasureMapper < BaseMapper
      self.entity_class = 'Measure'

      def mutate(attributes)
        attributes['measure_type_id'] = attributes.delete('measure_type')
        attributes['additional_code_id'] = attributes.delete('additional_code')
        attributes['geographical_area_id'] = attributes.delete('geographical_area')
        attributes['additional_code_type_id'] = attributes.delete('additional_code_type')
        attributes
      end
    end
  end
end
