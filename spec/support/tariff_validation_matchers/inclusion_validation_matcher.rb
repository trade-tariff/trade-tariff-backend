class InclusionValidationMatcher < TariffValidationMatcher
  attr_reader :collection

  def matches?(subject)
    @subject = subject.dup

    @validation = subject.conformance_validator
                         .validations
                         .detect do |validation|
      validation.type == validation_type &&
        validation.validation_options[:of] == @attributes &&
        validation.validation_options[:in] == @collection
    end
  end

  def in(collection)
    @collection = collection

    self
  end

  def failure_message
    msg = "expected #{subject.class.name} to validate #{validation_type} of #{attributes}"
    msg << " in #{collection}" if collection.present?
    msg
  end

  private

  def matches_collection?
    if collection.present?
      reflection_for(attributes.first)[:in] == collection
    else
      true
    end
  end
end

def validate_inclusion
  InclusionValidationMatcher.new(:inclusion)
end
