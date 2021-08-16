module TradeTariffBackend
  class Validator
    def self.validations
      @validations ||= []
      @validations
    end

    def self.validation(identifiers, description, opts = {}, &block)
      validations << ValidationDefiner.define(identifiers, description, opts, &block)
    end

    def validations
      self.class.validations
    end

    def validate(record)
      validations = relevant_validations_for(record).select do |validation|
        validation.operations.include?(record.operation)
      end

      validations.each do |validation|
        record.conformance_errors.add(validation.identifiers, validation.to_s) unless validation.valid?(record)
      end
    end

    def validate_for_operations(record, *operations)
      validations = relevant_validations_for(record).select do |validation|
        (validation.operations & operations).any?
      end

      validations.each do |validation|
        record.conformance_errors.add(validation.identifiers, validation.to_s) unless validation.valid?(record)
      end
    end

  private

    def relevant_validations_for(record)
      validations.select do |validation|
        validation.relevant_for?(record)
      end
    end
  end
end
