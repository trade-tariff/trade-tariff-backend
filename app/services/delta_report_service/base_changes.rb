class DeltaReportService
  class BaseChanges
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

          @change = current_value if change.blank?
          @changes << column.to_s.humanize.downcase
        end
      end
    end

    def date_of_effect
      if changes.include?('validity_start_date')
        record.validity_start_date
      elsif changes.include?('validity_end_date')
        record.validity_end_date
      elsif record.validity_start_date > record.operation_date
        record.validity_start_date
      else
        date
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
      when :delete
        "#{object_name} removed"
      end
    end
  end
end
