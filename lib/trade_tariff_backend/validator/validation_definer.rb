module TradeTariffBackend
  class Validator
    class ValidationDefiner
      attr_reader :identifiers, :description, :options, :validation_type, :validation_options

      def self.define(identifiers, description, opts, &block)
        raise ArgumentError, "#{self}.define expects to be provided with block" unless block_given?

        if block.arity.zero?
          new(identifiers, description, opts, &block).validation
        else
          generic_validation_klass.new(identifiers, description, opts, &block)
        end
      end

      def self.generic_validation_klass
        TradeTariffBackend::Validations::GenericValidation
      end

      def initialize(identifiers, description, options = {}, &block)
        @identifiers = identifiers
        @description = description
        @options = options

        instance_eval(&block)
      end

      def validates(validation_type, validation_options = {})
        @validation_type = validation_type
        @validation_options = validation_options
      end

      def validation
        raise ArgumentError, 'Validation block without arguments expects validation :validation_type to be provided' if validation_type.blank?

        validation_class_for(validation_type).new(identifiers, description, options.merge!(validation_options: validation_options))
      end

      private

      def validation_class_for(type)
        "TradeTariffBackend::Validations::#{type}Validation".underscore.classify.constantize
      rescue NameError
        raise ArgumentError, "You are trying to use undefined validator: #{type}"
      end
    end
  end
end
