class TariffChangesService
  class BaseChanges
    CREATION = 'creation'.freeze
    ENDING = 'ending'.freeze
    UPDATE = 'update'.freeze
    DELETION = 'deletion'.freeze

    attr_accessor :record, :changes, :change, :date

    def initialize(record, date)
      @record = record
      @date = date
      get_changes
    end

    def object_name
      raise NotImplementedError
    end

    def object_sid
      raise NotImplementedError
    end

    def excluded_columns
      %i[oid operation operation_date created_at updated_at filename]
    end

    def analyze
      return if no_changes?

      {
        type: object_name,
        object_sid: object_sid,
        goods_nomenclature_sid: record.goods_nomenclature_sid,
        goods_nomenclature_item_id: record.goods_nomenclature_item_id,
        action:,
        date_of_effect:,
        validity_start_date: record.validity_start_date&.to_date,
        validity_end_date: record.validity_end_date&.to_date,
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
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

          @changes << column.to_s
        end
      end
    end

    def date_of_effect
      if changes.include?('validity_start_date') && record.validity_start_date.present?
        record.validity_start_date.to_date
      elsif changes.include?('validity_end_date') && record.validity_end_date.present?
        (record.validity_end_date + 1.day).to_date
      elsif record.operation == :create && record.respond_to?(:validity_start_date) && record.validity_start_date.present?
        record.validity_start_date.to_date
      else
        date + 1.day
      end
    end

    def action
      case record.operation
      when :create
        CREATION
      when :update
        if changes.include?('validity_end_date')
          ENDING
        else
          UPDATE
        end
      when :destroy
        DELETION
      end
    end
  end
end
