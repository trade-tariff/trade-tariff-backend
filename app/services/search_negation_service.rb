class SearchNegationService
  NEGATION_TERMS = ['neither', 'other than', 'excluding', 'not', 'except', 'without'].freeze
  # (?<optional>,|-)? - This is a named capture group named 'optional' which matches either a comma ',' or a hyphen '-'.
  #                     The '?' makes this group optional, meaning it will match if a comma or hyphen is present, but it's not required.
  #
  # \s* - This matches zero or more whitespace characters. It's used here to allow for any spaces that might exist between the optional comma/hyphen and the excluded term.
  #
  # (?<excluded-term>neither|other than|excluding|not|except|without) - Another named capture group called 'excluded-term'.
  #                                                                     This group matches any one of the specified keywords, which are the excluded terms.
  #
  # \s+ - This matches one or more whitespace characters following the excluded term, ensuring that there is at least some space between the excluded term and the following text.
  #
  # ((?!-).)* - This is a negative lookahead contained within a non-capturing group.
  #             The negative lookahead (?!-) ensures that the character immediately following is not a hyphen '-'.
  #             The dot '.' matches any character except newline, and the asterisk '*' allows this pattern to repeat any number of times,
  #             effectively matching any sequence of characters that does not contain a hyphen.
  #             This ensures that the regex captures text following the excluded term up until a hyphen, if present.
  BRACKET_NEGATION_REGEX = /(?<excluded-bracket-area>\((#{NEGATION_TERMS.join('|')}).*\))/
  FULL_NEGATION_REGEX = /(?<optional>,|-)?\s*(?<excluded-term>#{NEGATION_TERMS.join('|')})\s+((?!-).)*/

  NO_BREAKING_SPACE = "\u00A0".freeze

  def initialize(text)
    @text = text
  end

  def call
    @text
      .to_s # Defensively convert nil to empty string
      .gsub(NO_BREAKING_SPACE, ' ')
      .gsub(BRACKET_NEGATION_REGEX, '') # Removes bracketed negation terms and their contents
      .gsub(FULL_NEGATION_REGEX, '') # Removes negation terms and their contents but preserves non-negating parts that follow
      .strip # Removes leading and trailing whitespace that may have resulted from the gsub pipeline above
  end
end
