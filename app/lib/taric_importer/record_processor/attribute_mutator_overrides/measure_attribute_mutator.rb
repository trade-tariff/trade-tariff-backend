class TaricImporter
  class RecordProcessor
    module AttributeMutatorOverrides
      class MeasureAttributeMutator
        # Avoid naming conflicts with associations.
        # Follow rails conventions where foreign keys are postfixed with '_id'
        def self.mutate(attributes)
          attributes['measure_type_id'] = attributes.delete('measure_type')
          attributes['additional_code_id'] = attributes.delete('additional_code')
          attributes['geographical_area_id'] = attributes.delete('geographical_area')
          attributes['additional_code_type_id'] = attributes.delete('additional_code_type')
          attributes
        end
      end
    end
  end
end
