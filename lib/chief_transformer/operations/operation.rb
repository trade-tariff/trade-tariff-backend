require 'forwardable'

class ChiefTransformer
  class Processor
    class Operation
      extend Forwardable

      def_delegator ActiveSupport::Notifications, :instrument

      attr_reader :record, :operation_date

      def initialize(record)
        @record = record
        @operation_date = record.operation_date
      end

      def update_record(record, attributes = {})
        record.set(attributes)

        unless record.conformant?
          record.invalidated_at = Time.now

          instrument('conformance_error.chief_transformer', record: record)
        end

        record.save
      end
    end
  end
end
