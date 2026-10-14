module Api
  module Shared
    module CsvSerializer
      extend ActiveSupport::Concern

      # A text cell that starts with one of these can run as a formula in spreadsheet tools
      # (OWASP CSV injection). Leading spaces are ignored because some tools trim them.
      FORMULA_TRIGGER = /\A(?:[\t\r]|\s*[=+\-@])/

      def self.escape_formula(value)
        value.is_a?(String) && FORMULA_TRIGGER.match?(value) ? "'#{value}" : value
      end

      def initialize(serializables, options = {})
        @serializables = serializables
        @options = options
      end

      def serializable_array
        @serializables.each_with_object([header_row]) do |serializable, acc|
          data_row = column_options.map do |column_option|
            value = if column_option[:value_block].present?
                      column_option[:value_block].call(serializable)
                    else
                      serializable.public_send(column_option[:column])
                    end

            self.class.escape_formulas? ? CsvSerializer.escape_formula(value) : value
          end

          acc << data_row
        end
      end

      def serialized_csv
        CSV.generate do |csv|
          serializable_array.each do |row|
            csv << row
          end
        end
      end

      delegate :column_options, to: :class

    private

      def header_row
        column_options.pluck(:column_name)
      end

      module ClassMethods
        def columns(*column_options)
          column_options.each(&method(:column))
        end

        def column(column, options = {}, &block)
          (self.column_options ||= []) << options.reverse_merge(column:, column_name: column, value_block: block)
        end

        def column_options
          @column_options ||= []
        end

        # Opt in for serializers with untrusted text. Prefixes risky text cells with an apostrophe
        # so spreadsheet tools show them as text. Not the default, as it would change values such
        # as "-5" in existing reports.
        def escape_formulas!
          @escape_formulas = true
        end

        def escape_formulas?
          @escape_formulas == true
        end
      end
    end
  end
end
