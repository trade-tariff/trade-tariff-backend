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
          @serializables.each_with_object(initial_rows) do |serializable, acc|
            data_row = columns.map do |column|
              serializable.public_send(column)
            end

            acc << data_row
          end
        end

        def serialized_csv
          serialized = CSV.generate do |csv|
            serializable_array.each do |row|
              csv << row
            end
          end

          serialized.html_safe
        end

        def initial_rows
          [columns]
        end

        delegate :columns, to: :class

        module ClassMethods
          def columns(*column_list)
            if column_list.compact.present?
              column_list.each do |column|
                (@columns ||= []) << column
              end
            else
              (@columns ||= [])
            end
          end

          def column(column)
            (@columns ||= []) << column
          end
        end
      end
    end
  end
end
