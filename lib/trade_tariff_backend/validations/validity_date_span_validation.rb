module TradeTariffBackend
  module Validations
    class ValidityDateSpanValidation < GenericValidation
      def valid?(record = nil)
      association = validation_options[:of]

      raise ArgumentError.new('validates :validity_date_span excepts of: option to be provided') if association.blank?

      associated_records = [record.send(association)].flatten.compact.select { |record|
        # not new == persisted
        !record.new?
      }

      associated_records.none? || associated_records.all?{ |associated_record|
        (record.validity_start_date.to_date >= associated_record.validity_start_date.to_date) &&
        ((record.validity_end_date.blank? && associated_record.validity_end_date.blank?) ||
         (record.validity_end_date.present? && associated_record.validity_end_date.present? && record.validity_end_date.to_date <= associated_record.validity_end_date.to_date) ||
         (record.validity_end_date.present? && associated_record.validity_end_date.blank?))
      }
      end
    end
  end
end
