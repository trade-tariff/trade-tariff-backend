module Api
  module V2
    module Csv
      module CsvSerializer
        extend ActiveSupport::Concern

        def initialize(serializables, options = {})
          @serializables = serializables
          @options = options
        end

        def serializable_array
          @serializables.each_with_object([header_row]) do |serializable, acc|
            data_row = column_options.map do |column_option|
              if column_option[:value_block].present?
                column_option[:value_block].call(serializable)
              else
                serializable.public_send(column_option[:column])
              end
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
          column_options.map do |column_option|
            column_option[:column_name]
          end
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
        end
      end
    end
  end
end
