class InputValidationMatcher < TariffValidationMatcher
  attr_reader :required_condition

  def matches?(subject)
    super && matches_required_condition?
  end

  def description
    if required_condition.present?
      "validate #{validation_type} of #{attributes} and require #{required_condition} to return true"
    else
      super
    end
  end

  def failure_message
    msg = "expected #{subject.class.name} to validate #{validation_type} of #{attributes}"
    msg << " and require #{required_condition} to return true" if required_condition.present?
    msg
  end

  def requires(condition)
    @required_condition = condition

    self
  end

  private

  def matches_required_condition?
    if required_condition.present?
      attributes.all? do |attribute|
        reflection_for(attribute)[:requires] == required_condition
      end
    else
      true
    end
  end
end

def validate_input
  InputValidationMatcher.new(:input)
end
