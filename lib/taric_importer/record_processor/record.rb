require 'taric_importer/record_processor/attribute_mutator'

# Can also mutate attributes for all record operations, e.g.:
#
#  class LanguageAttributeMutator < AttributeMutator
#    def self.mutate(attributes)
#      attributes[:a] = 'b'
#      attributes   # do not forget to return it
#    end
#  end

Dir[File.join(Rails.root, 'lib', 'taric_importer', 'record_processor', 'attribute_mutator_overrides', '*.rb')].each {|file|
  require file
}

class TaricImporter
  class RecordProcessor
    class Record
      include TaricImporter::Helpers::StringHelper

      # Entity class, e.g. Measure
      attr_accessor :klass

      # Entity primary key, i.e. Measure.primary_key
      attr_accessor :primary_key

      # Sanitized and processed attributes
      attr_reader :attributes

      # TARIC transaction ID
      attr_accessor :transaction_id

      def initialize(record_hash)
        self.transaction_id = record_hash['transaction_id']
        self.klass = fast_classify(record_hash.keys.last).constantize
        self.primary_key = [klass.primary_key].flatten.map(&:to_s)
        self.attributes = record_hash.values.last
      end

      def attributes=(attrs)
        attrs = mutate_attributes(attrs)
        @attributes = default_attributes.merge(attrs)
      end

      private

      def default_attributes
        klass.columns.reduce({}) do |memo, column_name|
          memo.merge!({column_name.to_s => nil})
        end
      end

      def mutate_attributes(attributes)
        mutator_class = "TaricImporter::RecordProcessor::#{klass}AttributeMutator"
        if Object.const_defined?(mutator_class)
          mutator_class.constantize.mutate(attributes)
        else
          TaricImporter::RecordProcessor::AttributeMutator.mutate(attributes)
        end
      end
    end
  end
end
