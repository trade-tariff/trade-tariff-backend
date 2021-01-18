module TradeTariffBackend
  module Validations
    class PresenceValidation < GenericValidation
      def valid?(record = nil)
        args = validation_options[:of]

        raise ArgumentError.new('validates presence expects of:[Array] to be passed in') if args.blank?

        [args].flatten.all? {|arg|
          record.send(arg.to_sym).present?
        }
      end
    end
  end
end
