# Uniqueness validation does not need additional checks besides
# metadata
class UniquenessValidationMatcher < TariffValidationMatcher
  def matches?(subject)
    super

    subject.conformance_validator
           .validations
           .select { |validation| validation.type == validation_type }
           .any? do |validation|
      [validation.validation_options[:of]].flatten == [@attributes].flatten
    end
  end
end

def validate_uniqueness
  UniquenessValidationMatcher.new(:uniqueness)
end
