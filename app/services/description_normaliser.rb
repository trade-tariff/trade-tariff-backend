class DescriptionNormaliser
  UNICODE_TO_ASCII = {
    "\u2018" => "'",        # left single quotation mark
    "\u2019" => "'",        # right single quotation mark
    "\u201C" => '"',        # left double quotation mark
    "\u201D" => '"',        # right double quotation mark
    "\u2013" => '-',        # en-dash
    "\u2011" => '-',        # non-breaking hyphen
    "\u2212" => '-',        # minus sign
    "\u00A0" => ' ',        # non-breaking space
    "\u2265" => '>=',       # greater-than or equal to
    "\u2264" => '<=',       # less-than or equal to
    "\u00D7" => 'x',        # multiplication sign
    "\u2103" => 'degrees C', # degree celsius
  }.freeze

  HTML_ENTITY_MAP = {
    '&ge;' => '>=',
    '&le;' => '<=',
    '&times;' => 'x',
    '&deg;' => ' degrees ',
    '&amp;' => '&',
    '&nbsp;' => ' ',
  }.freeze

  def self.call(str)
    return '' if str.blank?

    result = str.dup

    # Convert specific tags to meaningful replacements
    result.gsub!(/<br\s*\/?>/, ' ')
    result.gsub!(/<p\/>/, ' ')
    result.gsub!(/<\/?(sup|sub)>/, '')

    # Decode HTML entities before Loofah (which would decode them to Unicode)
    HTML_ENTITY_MAP.each { |entity, replacement| result.gsub!(entity, replacement) }
    result.gsub!(/&#(\d+);/) { [::Regexp.last_match(1).to_i].pack('U') }
    result.gsub!(/&#x([0-9a-f]+);/i) { [::Regexp.last_match(1).hex].pack('U') }

    # Strip control characters before Loofah (which would replace null bytes with spaces)
    result.gsub!(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')

    # Strip remaining HTML tags via Loofah (handles nested/malformed markup)
    result = Loofah.fragment(result).text(encode_special_chars: false)

    # Normalize Unicode to ASCII
    UNICODE_TO_ASCII.each { |char, replacement| result.gsub!(char, replacement) }

    # Strip any control characters Loofah may have reintroduced
    result.gsub!(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')

    # Ensure valid UTF-8
    unless result.valid_encoding?
      result = result.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end

    # Collapse whitespace
    result.gsub!(/\s+/, ' ')
    result.strip
  end
end
