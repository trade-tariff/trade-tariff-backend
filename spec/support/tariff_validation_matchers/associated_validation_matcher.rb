class AssociatedValidationMatcher < TariffValidationMatcher
  attr_reader :associated_object, :ensurance_method

  def initialize(validation_type, associated_object)
    @associated_object = associated_object

    super(validation_type)
  end

  def matches?(subject)
    @attributes = [associated_object]

    super
  end

  def and_ensure(ensurance_method)
    @ensurance_method = ensurance_method

    self
  end

  def description
    if ensurance_method.present?
      "validate #{validation_type} #{associated_object} and ensure that #{ensurance_method} is truthy"
    else
      "validate #{validation_type} #{associated_object}"
    end
  end

  def failure_message
    "expected #{subject.class.name} to validate #{validation_type} #{associated_object} and ensure that #{ensurance_method} is truthy"
  end

  private

  def validate(reflections)
    if reflections.present?
      reflections.detect  do |validation, opts|
        validation == validation_type &&
          (condition.blank? ? true : opts[:if] == condition) &&
          (ensurance_method.blank? ? true : opts[:ensure] == ensurance_method)
      end
    end
  end
end

def validate_associated(associated_object)
  AssociatedValidationMatcher.new(:associated, associated_object)
end
