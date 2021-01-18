class LengthValidationMatcher < TariffValidationMatcher
  LENGTH_OPTS = %i[maximum minimum exact].freeze

  attr_reader :maximum_length, :minimum_length, :exact_length

  def matches?(subject)
    super && matches_length?
  end

  LENGTH_OPTS.each do |opt|
    define_method(opt.to_sym) do |length|
      instance_variable_set("@#{opt}_length", length)

      self
    end

    define_method("matches_#{opt}?".to_sym) do
      if send("#{opt}_length".to_sym).present?
        attributes.all? do |attribute|
          reflection_for(attribute)[opt] == send("#{opt}_length".to_sym)
        end
      else
        true
      end
    end
  end

  def failure_message
    msg = "expected #{subject.class.name} to validate #{validation_type} of #{attributes}"
    LENGTH_OPTS.each do |opt|
      msg << " #{opt}: #{send("#{opt}_length")}" if send("#{opt}_length".to_sym).present?
    end
    msg
  end

  private

  def matches_length?
    matches_minimum? && matches_maximum? && matches_exact?
  end
end

def validate_length
  LengthValidationMatcher.new(:length)
end
