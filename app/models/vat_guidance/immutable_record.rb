module VatGuidance
  module ImmutableRecord
    IMMUTABLE_MESSAGE = 'VAT guidance records are immutable after insert'.freeze

    def before_update
      raise Sequel::ValidationFailed, IMMUTABLE_MESSAGE
    end

    def before_destroy
      raise Sequel::ValidationFailed, IMMUTABLE_MESSAGE
    end

    def delete
      raise Sequel::ValidationFailed, IMMUTABLE_MESSAGE
    end
  end
end
