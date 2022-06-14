class TaricImporter
  class RecordProcessor
    module AttributeMutatorOverrides
      class GoodsNomenclatureAttributeMutator < TaricImporter::RecordProcessor::AttributeMutator
        def self.mutate(attributes)
          attributes['path'] = Sequel.pg_array([], :integer)
          attributes
        end
      end
    end
  end
end
