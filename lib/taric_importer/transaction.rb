require 'forwardable'

class TaricImporter
  class Transaction
    extend Forwardable

    def_delegator ActiveSupport::Notifications, :instrument

    def initialize(transaction, issue_date)
      @transaction = transaction
      @issue_date = issue_date
      @record = nil

      verify_transaction
    end

    def persist
      @record = RecordProcessor.new(@transaction, @issue_date).process!
    end

  private

    def verify_transaction
      if @transaction['transaction_id'].blank?
        raise ArgumentError.new('TARIC transaction does not have required attributes')
      end
    end
  end
end
