class AiResponseSanitizer
  # PostgreSQL cannot store null bytes (\u0000) in text/JSON columns
  # AI responses may contain these characters which cause PG::UntranslatableCharacter errors
  NULL_BYTE = "\u0000".freeze

  # Other problematic Unicode characters that may appear in AI responses
  PROBLEMATIC_PATTERNS = [
    NULL_BYTE,                    # Null byte - PostgreSQL cannot store
    "\uFFFE",                     # Byte order mark (invalid)
    "\uFFFF",                     # Not a character
  ].freeze

  def initialize(response)
    @response = response
  end

  def call
    sanitize(@response)
  end

  class << self
    def call(response)
      new(response).call
    end
  end

  private

  def sanitize(value)
    case value
    when String
      sanitize_string(value)
    when Hash
      value.transform_values { |v| sanitize(v) }
    when Array
      value.map { |v| sanitize(v) }
    else
      value
    end
  end

  def sanitize_string(str)
    result = str.dup

    PROBLEMATIC_PATTERNS.each do |pattern|
      result.gsub!(pattern, '')
    end

    # Strip C0 control characters (U+0001-U+001F) except tab, newline, carriage return
    result.gsub!(/[\x01-\x08\x0B\x0C\x0E-\x1F]/, '')

    # Normalize common Unicode that LLMs produce
    DescriptionHtmlFormatter::UNICODE_TO_ASCII.each do |char, replacement|
      result.gsub!(char, replacement)
    end

    # Ensure valid UTF-8 encoding
    unless result.valid_encoding?
      result = result.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end

    result
  end
end
