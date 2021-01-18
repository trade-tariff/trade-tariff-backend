class ExclusionValidationMatcher < TariffValidationMatcher
  attr_reader :collection

  def matches?(subject)
    @subject = subject.dup

    @validation = subject.conformance_validator
                         .validations
                         .detect do |validation|
      validation.type == validation_type
      (validation.validation_options[:from].is_a?(Array) && validation.validation_options[:from] == collection) ||
        (validation.validation_options[:from].is_a?(Proc) && validation.validation_options[:from].call == collection.call) &&
          validation.validation_options[:of] == attributes
    end
  end

  def from(collection)
    @collection = collection

    self
  end

  def failure_message
    msg = "expected #{subject.class.name} to validate #{validation_type} of #{attributes}"
    msg << " from #{collection}" if collection.present?
    msg
  end

  private

  def matches_collection?
    if collection.present?
      reflection_for(attributes.first)[:from] == collection
    else
      true
    end
  end
end

def validate_exclusion
  ExclusionValidationMatcher.new(:exclusion)
end
