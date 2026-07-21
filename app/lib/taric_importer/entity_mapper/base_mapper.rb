# frozen_string_literal: true

class TaricImporter
  class EntityMapper
    class BaseMapper
      class << self
        attr_accessor :entity_class
      end

      attr_reader :record_hash, :klass

      def initialize(record_hash, klass)
        @record_hash = record_hash
        @klass = klass
      end

      def primary_key
        [klass.primary_key].flatten.map(&:to_s)
      end

      # Merge order matters: mutate the raw XML keys first (e.g. 'measure_type' -> 'measure_type_id'),
      # then overlay onto the nil-filled column set, then run any create-time hooks (e.g. SID
      # synthesis)
      def attributes(operation)
        @attributes ||= {}
        @attributes[operation] ||= before_build(default_attributes.merge(mutate(record_hash.values.last)), operation)
      end

      def mutate(attributes) = attributes
      def before_build(attributes, _operation) = attributes

    private

      def default_attributes
        klass.columns.each_with_object({}) { |column_name, memo| memo[column_name.to_s] = nil }
      end
    end
  end
end
