class DeltaReportService
  class BaseChanges
    include DeltaPresenter

    attr_accessor :record, :changes, :change, :date

    def initialize(record, date)
      @record = record
      @date = date
      get_changes
    end

    def object_name
      raise NotImplementedError
    end

    def excluded_columns
      %i[oid operation operation_date created_at updated_at filename]
    end

    def no_changes?
      record.operation == :update && changes.empty?
    end

    def get_changes
      @changes = []

      return unless record.operation == :update

      if (previous_record = record.previous_record)
        comparable_columns = record.values.keys - excluded_columns

        comparable_columns.each do |column|
          current_value = record.send(column)
          previous_value = previous_record.try(column)

          next if current_value == previous_value

          column = { validity_start_date: :start_date,
                     validity_end_date: :end_date }[column] || column

          @change ||= if column == :start_date
                        current_value.to_date.iso8601
                      elsif column == :end_date
                        if current_value.nil?
                          'Removed'
                        else
                          (current_value.to_date + 1.day)&.iso8601
                        end
                      else
                        current_value
                      end

          @changes << column.to_s.humanize.downcase
        end
      end
    end

    def date_of_effect
      if changes.include?('start date') && record.validity_start_date.present?
        record.validity_start_date
      elsif changes.include?('end date') && record.validity_end_date.present?
        record.validity_end_date + 1.day
      elsif record.operation == :create && record.respond_to?(:validity_start_date)
        record.validity_start_date
      else
        date + 1.day
      end
    end

    def description
      case record.operation
      when :create
        "#{object_name} added"
      when :update
        if changes.any?
          "#{object_name} #{changes.join(', ')} updated"
        else
          "#{object_name} updated"
        end
      when :destroy
        "#{object_name} removed"
      end
    end
  end
end
