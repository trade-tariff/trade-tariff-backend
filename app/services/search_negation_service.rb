class SearchNegationService
  NEGATION_REGEX = /, (?<excluded-term>neither|other than|excluding|not|except) .*/
  NO_BREAKING_SPACE = "\u00A0".freeze

  def initialize(text)
    @text = text
  end

  def call
    result = @text.to_s.gsub(NO_BREAKING_SPACE, ' ')
    result.gsub(NEGATION_REGEX, '')
  end
end
