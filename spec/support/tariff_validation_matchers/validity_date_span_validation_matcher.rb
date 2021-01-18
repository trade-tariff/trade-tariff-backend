class ValidityDateSpanMatcher < TariffValidationMatcher
  def matches?(subject)
    super

    subject.conformance_validator
           .validations
           .select { |validation| validation.type == validation_type }
           .any? do |validation|
      validation.validation_options[:of] == @attributes
    end
  end
end

def validate_validity_date_span
  ValidityDateSpanMatcher.new(:validity_date_span)
end
